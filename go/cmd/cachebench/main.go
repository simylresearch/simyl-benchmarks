// cachebench measures gateway_cache (Go) under a replayed request trace.
//
// Every implementation measured in this repository follows the same protocol:
// a trace of key indices is replayed by W workers (each starting at a different
// offset), each request calls the cache's "get or compute" operation, the miss
// solver sleeps for a configurable latency, and per-request latency is recorded
// in a log-linear histogram (16 sub-buckets per power of two). The run ends
// after a fixed duration; results are appended as one JSON object per line.
package main

import (
	"encoding/binary"
	"encoding/json"
	"flag"
	"fmt"
	"math/bits"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	gw "github.com/geniussportsgroup/gateway_cache/v3"
)

const implVersion = "github.com/geniussportsgroup/gateway_cache/v3 v3.1.0"

// Value is the cached payload: an identifier plus 64 bytes, as in the C++ benchmark.
type Value struct {
	ID      int
	Payload [64]byte
}

// hist is a log-linear histogram of nanoseconds: 16 sub-buckets per power of two.
type hist struct {
	buckets [64 * 16]uint64
	count   uint64
	sum     uint64
	max     uint64
}

func bucketIndex(v uint64) int {
	if v < 16 {
		return int(v)
	}
	exp := bits.Len64(v) - 1
	sub := (v >> uint(exp-4)) & 15
	return exp*16 + int(sub)
}

func bucketLower(idx int) uint64 {
	if idx < 16 {
		return uint64(idx)
	}
	exp, sub := idx/16, idx%16
	return uint64(16+sub) << uint(exp-4)
}

func (h *hist) record(ns uint64) {
	h.buckets[bucketIndex(ns)]++
	h.count++
	h.sum += ns
	if ns > h.max {
		h.max = ns
	}
}

func (h *hist) merge(o *hist) {
	for i := range h.buckets {
		h.buckets[i] += o.buckets[i]
	}
	h.count += o.count
	h.sum += o.sum
	if o.max > h.max {
		h.max = o.max
	}
}

// percentile returns the lower bound of the bucket holding the p-th percentile (0..1).
func (h *hist) percentile(p float64) uint64 {
	if h.count == 0 {
		return 0
	}
	target := uint64(p * float64(h.count))
	if target == 0 {
		target = 1
	}
	var acc uint64
	for i, c := range h.buckets {
		acc += c
		if acc >= target {
			return bucketLower(i)
		}
	}
	return h.max
}

// rssMB reads the resident set size from /proc/self/status (Linux); 0 elsewhere.
func rssMB() float64 {
	raw, err := os.ReadFile("/proc/self/status")
	if err != nil {
		return 0
	}
	for _, line := range strings.Split(string(raw), "\n") {
		if strings.HasPrefix(line, "VmRSS:") {
			f := strings.Fields(line)
			if len(f) >= 2 {
				kb, _ := strconv.ParseFloat(f[1], 64)
				return kb / 1024
			}
		}
	}
	return 0
}

func loadTrace(path string) ([]uint32, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	if len(raw)%4 != 0 || len(raw) == 0 {
		return nil, fmt.Errorf("trace %s: size %d is not a non-empty multiple of 4", path, len(raw))
	}
	trace := make([]uint32, len(raw)/4)
	for i := range trace {
		trace[i] = binary.LittleEndian.Uint32(raw[4*i:])
	}
	return trace, nil
}

type result struct {
	Impl          string  `json:"impl"`
	Version       string  `json:"version"`
	Scenario      string  `json:"scenario"`
	Keys          int     `json:"keys"`
	Workers       int     `json:"workers"`
	Capacity      int     `json:"capacity"`
	TTLMs         float64 `json:"ttl_ms"`
	SolverLatUs   float64 `json:"solver_latency_us"`
	WarmupS       float64 `json:"warmup_s"`
	DurationS     float64 `json:"duration_s"`
	Requests      uint64  `json:"requests"`
	ThroughputRPS float64 `json:"throughput_rps"`
	MeanUs        float64 `json:"mean_us"`
	P50Us         float64 `json:"p50_us"`
	P90Us         float64 `json:"p90_us"`
	P99Us         float64 `json:"p99_us"`
	P999Us        float64 `json:"p999_us"`
	MaxUs         float64 `json:"max_us"`
	SolverCalls   uint64  `json:"solver_calls"`
	Hits          int     `json:"hits"`
	Misses        int     `json:"misses"`
	Errors        uint64  `json:"errors"`
	RSSMB         float64 `json:"rss_mb"`
	Runtime       string  `json:"runtime"`
	MaxProcs      int     `json:"max_procs"`
	StartedAt     string  `json:"started_at"`
}

func main() {
	var (
		tracePath = flag.String("trace", "", "binary trace of little-endian uint32 key indices")
		keys      = flag.Int("keys", 0, "number of distinct keys the trace was generated for")
		workers   = flag.Int("workers", runtime.NumCPU(), "concurrent workers")
		capacity  = flag.Int("capacity", 1000, "cache capacity (entries)")
		ttl       = flag.Duration("ttl", time.Second, "time to live of a cached value")
		solverLat = flag.Duration("solver-latency", 0, "simulated backend latency inside the miss solver")
		warmup    = flag.Duration("warmup", 2*time.Second, "unmeasured warm-up period")
		duration  = flag.Duration("duration", 10*time.Second, "measured period")
		scenario  = flag.String("scenario", "", "scenario name recorded in the output")
		out       = flag.String("out", "", "file to append the JSON result line to (default: stdout)")
	)
	flag.Parse()
	if *tracePath == "" || *keys <= 0 || *workers <= 0 {
		fmt.Fprintln(os.Stderr, "usage: cachebench -trace FILE -keys N [-workers W] [-capacity C] [-ttl D] [-solver-latency D] [-warmup D] [-duration D] [-scenario NAME] [-out FILE]")
		os.Exit(2)
	}
	trace, err := loadTrace(*tracePath)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	var solverCalls atomic.Uint64
	lat := *solverLat
	solver := func(k int, _ ...interface{}) (Value, *gw.RequestError) {
		solverCalls.Add(1)
		if lat > 0 {
			time.Sleep(lat)
		}
		v := Value{ID: k}
		copy(v.Payload[:], strconv.Itoa(k))
		return v, nil
	}
	toKey := func(k int) (string, error) { return strconv.Itoa(k), nil }
	cache := gw.New[int, Value](*capacity, 0.5, *ttl, *ttl, solver, toKey)

	var (
		measuring atomic.Bool
		stop      atomic.Bool
		hists     = make([]hist, *workers)
		counts    = make([]uint64, *workers)
		errors    atomic.Uint64
		wg        sync.WaitGroup
	)
	n := len(trace)
	immediate := *warmup <= 0 // cold-start scenarios: measure from the first request
	hits0, misses0, calls0 := cache.HitCount(), cache.MissCount(), solverCalls.Load()
	startedAt := time.Now()
	if immediate {
		measuring.Store(true)
	}
	for w := 0; w < *workers; w++ {
		wg.Add(1)
		go func(w int) {
			defer wg.Done()
			h := &hists[w]
			pos := (w * n) / *workers
			for !stop.Load() {
				k := int(trace[pos])
				pos++
				if pos == n {
					pos = 0
				}
				t0 := time.Now()
				_, rerr := cache.RetrieveFromCacheOrCompute(k)
				ns := uint64(time.Since(t0).Nanoseconds())
				if measuring.Load() {
					h.record(ns)
					counts[w]++
					if rerr != nil {
						errors.Add(1)
					}
				}
			}
		}(w)
	}
	if !immediate {
		time.Sleep(*warmup)
		hits0, misses0, calls0 = cache.HitCount(), cache.MissCount(), solverCalls.Load()
		startedAt = time.Now()
		measuring.Store(true)
	}
	time.Sleep(*duration)
	measuring.Store(false)
	elapsed := time.Since(startedAt)
	stop.Store(true)
	wg.Wait()
	hits1, misses1, calls1 := cache.HitCount(), cache.MissCount(), solverCalls.Load()

	var total hist
	for w := range hists {
		total.merge(&hists[w])
	}
	us := func(ns uint64) float64 { return float64(ns) / 1e3 }
	r := result{
		Impl: "gateway_cache", Version: implVersion, Scenario: *scenario,
		Keys: *keys, Workers: *workers, Capacity: *capacity,
		TTLMs: float64(ttl.Microseconds()) / 1e3, SolverLatUs: float64(solverLat.Nanoseconds()) / 1e3,
		WarmupS: warmup.Seconds(), DurationS: elapsed.Seconds(),
		Requests: total.count, ThroughputRPS: float64(total.count) / elapsed.Seconds(),
		MeanUs: us(total.sum) / float64(max(total.count, 1)),
		P50Us:  us(total.percentile(0.50)), P90Us: us(total.percentile(0.90)),
		P99Us: us(total.percentile(0.99)), P999Us: us(total.percentile(0.999)), MaxUs: us(total.max),
		SolverCalls: calls1 - calls0, Hits: hits1 - hits0, Misses: misses1 - misses0, Errors: errors.Load(),
		RSSMB: rssMB(), Runtime: runtime.Version(), MaxProcs: runtime.GOMAXPROCS(0),
		StartedAt: startedAt.UTC().Format(time.RFC3339),
	}
	line, _ := json.Marshal(r)
	if *out == "" {
		fmt.Println(string(line))
		return
	}
	f, err := os.OpenFile(*out, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer f.Close()
	fmt.Fprintln(f, string(line))
	fmt.Fprintf(os.Stderr, "%s workers=%d rps=%.0f p50=%.1fus p99=%.1fus solver_calls=%d hits=%d misses=%d\n",
		r.Scenario, r.Workers, r.ThroughputRPS, r.P50Us, r.P99Us, r.SolverCalls, r.Hits, r.Misses)
}
