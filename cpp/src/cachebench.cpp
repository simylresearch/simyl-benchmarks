// cachebench measures cpp-cache (C++20) under a replayed request trace.
// Same protocol as the Go harness: W workers replay a trace of key indices from
// different offsets, every request calls get_or_compute, the miss solver sleeps
// for a configurable latency, per-request latency goes into a log-linear
// histogram (16 sub-buckets per power of two), and the run lasts a fixed time.
#include <cache/cache.H>

#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iostream>
#include <memory>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

using namespace std::chrono;

struct Value
{
  int id = 0;
  char payload[64] = {};
};

struct Hist
{
  uint64_t buckets[64 * 16] = {};
  uint64_t count = 0, sum = 0, max = 0;

  static int index(uint64_t v)
  {
    if (v < 16) return int(v);
    int exp = 63 - __builtin_clzll(v);
    int sub = int((v >> (exp - 4)) & 15);
    return exp * 16 + sub;
  }
  static uint64_t lower(int idx)
  {
    if (idx < 16) return uint64_t(idx);
    int exp = idx / 16, sub = idx % 16;
    return uint64_t(16 + sub) << (exp - 4);
  }
  void record(uint64_t ns)
  {
    buckets[index(ns)]++; count++; sum += ns; if (ns > max) max = ns;
  }
  void merge(const Hist &o)
  {
    for (size_t i = 0; i < 64 * 16; ++i) buckets[i] += o.buckets[i];
    count += o.count; sum += o.sum; if (o.max > max) max = o.max;
  }
  uint64_t percentile(double p) const
  {
    if (count == 0) return 0;
    uint64_t target = uint64_t(p * double(count));
    if (target == 0) target = 1;
    uint64_t acc = 0;
    for (size_t i = 0; i < 64 * 16; ++i)
      {
        acc += buckets[i];
        if (acc >= target) return lower(int(i));
      }
    return max;
  }
};

static double rss_mb()
{
  std::ifstream st("/proc/self/status");
  std::string line;
  while (std::getline(st, line))
    if (line.rfind("VmRSS:", 0) == 0)
      {
        std::istringstream is(line.substr(6));
        double kb = 0; is >> kb; return kb / 1024.0;
      }
  return 0;
}

static std::vector<uint32_t> load_trace(const std::string &path)
{
  std::ifstream in(path, std::ios::binary | std::ios::ate);
  if (!in) throw std::runtime_error("cannot open trace " + path);
  auto size = in.tellg();
  if (size <= 0 || size % 4 != 0) throw std::runtime_error("trace size is not a non-empty multiple of 4");
  std::vector<uint32_t> trace(size_t(size) / 4);
  in.seekg(0);
  in.read(reinterpret_cast<char *>(trace.data()), size);
  return trace;  // little-endian host assumed (x86-64, aarch64)
}

static long long parse_duration_us(const std::string &s)
{
  // Accepts Go-style durations: 10s, 500ms, 2000us, 1m.
  size_t i = 0; while (i < s.size() && (isdigit(s[i]) || s[i] == '.')) ++i;
  double v = std::stod(s.substr(0, i)); std::string u = s.substr(i);
  if (u == "s") return (long long) (v * 1e6);
  if (u == "ms") return (long long) (v * 1e3);
  if (u == "us" || u == "µs") return (long long) v;
  if (u == "m") return (long long) (v * 60e6);
  if (u == "ns") return (long long) (v / 1e3);
  throw std::runtime_error("bad duration " + s);
}

int main(int argc, char **argv)
{
  std::string trace_path, scenario, out;
  int keys = 0, workers = int(std::thread::hardware_concurrency()), capacity = 1000;
  long long ttl_us = 1'000'000, solver_us = 0, warmup_us = 2'000'000, duration_us = 10'000'000;
  for (int i = 1; i < argc; ++i)
    {
      std::string a = argv[i];
      auto need = [&](const char *name) { if (i + 1 >= argc) { std::cerr << "missing value for " << name << "\n"; exit(2); } return std::string(argv[++i]); };
      if (a == "-trace") trace_path = need("-trace");
      else if (a == "-keys") keys = std::stoi(need("-keys"));
      else if (a == "-workers") workers = std::stoi(need("-workers"));
      else if (a == "-capacity") capacity = std::stoi(need("-capacity"));
      else if (a == "-ttl") ttl_us = parse_duration_us(need("-ttl"));
      else if (a == "-solver-latency") solver_us = parse_duration_us(need("-solver-latency"));
      else if (a == "-warmup") warmup_us = parse_duration_us(need("-warmup"));
      else if (a == "-duration") duration_us = parse_duration_us(need("-duration"));
      else if (a == "-scenario") scenario = need("-scenario");
      else if (a == "-out") out = need("-out");
      else { std::cerr << "unknown flag " << a << "\n"; return 2; }
    }
  if (trace_path.empty() || keys <= 0 || workers <= 0)
    {
      std::cerr << "usage: cachebench-cpp -trace FILE -keys N [-workers W] [-capacity C] [-ttl D] [-solver-latency D] [-warmup D] [-duration D] [-scenario NAME] [-out FILE]\n";
      return 2;
    }
  if (ttl_us % 1'000'000 != 0 || ttl_us <= 0)
    {
      std::cerr << "cpp-cache takes the TTL in whole seconds; got " << ttl_us << " us\n";
      return 2;
    }

  auto trace = load_trace(trace_path);
  std::atomic<uint64_t> solver_calls{0}, solver_ns{0};
  const microseconds solver_latency(solver_us);
  using CacheT = CppCache::Cache<std::string, Value>;
  CacheT cache(size_t(capacity), seconds(ttl_us / 1'000'000), seconds(ttl_us / 1'000'000),
               [&](const std::string &k) -> std::shared_ptr<Value>
               {
                 solver_calls.fetch_add(1, std::memory_order_relaxed);
                 if (solver_latency.count() > 0)
                   {
                     auto t0 = steady_clock::now();
                     std::this_thread::sleep_for(solver_latency);
                     solver_ns.fetch_add(uint64_t(duration_cast<nanoseconds>(steady_clock::now() - t0).count()), std::memory_order_relaxed);
                   }
                 auto v = std::make_shared<Value>();
                 v->id = std::stoi(k);
                 std::strncpy(v->payload, k.c_str(), sizeof(v->payload) - 1);
                 return v;
               });

  std::atomic<bool> measuring{false}, stop{false};
  std::atomic<uint64_t> errors{0};
  std::vector<Hist> hists(static_cast<size_t>(workers));
  std::vector<std::thread> threads;
  const size_t n = trace.size();
  const bool immediate = warmup_us <= 0;  // cold-start scenarios: measure from the first request
  auto s0 = cache.stats(); auto calls0 = solver_calls.load(); auto ns0 = solver_ns.load();
  auto started = system_clock::now();
  auto t_start = steady_clock::now();
  if (immediate) measuring.store(true);
  for (int w = 0; w < workers; ++w)
    threads.emplace_back([&, w]
    {
      Hist &h = hists[size_t(w)];
      size_t pos = (size_t(w) * n) / size_t(workers);
      std::string key;
      while (!stop.load(std::memory_order_relaxed))
        {
          key = std::to_string(trace[pos]);
          if (++pos == n) pos = 0;
          auto t0 = steady_clock::now();
          auto r = cache.get_or_compute(key);
          auto ns = uint64_t(duration_cast<nanoseconds>(steady_clock::now() - t0).count());
          if (measuring.load(std::memory_order_relaxed))
            {
              h.record(ns);
              if (!r.is_positive()) errors.fetch_add(1, std::memory_order_relaxed);
            }
        }
    });
  if (!immediate)
    {
      std::this_thread::sleep_for(microseconds(warmup_us));
      s0 = cache.stats(); calls0 = solver_calls.load(); ns0 = solver_ns.load();
      started = system_clock::now();
      t_start = steady_clock::now();
      measuring.store(true);
    }
  std::this_thread::sleep_for(microseconds(duration_us));
  measuring.store(false);
  double elapsed = duration<double>(steady_clock::now() - t_start).count();
  stop.store(true);
  for (auto &t : threads) t.join();
  auto s1 = cache.stats(); auto calls1 = solver_calls.load(); auto ns1 = solver_ns.load();
  const double solver_mean_us = calls1 > calls0 ? double(ns1 - ns0) / 1e3 / double(calls1 - calls0) : 0.0;

  Hist total;
  for (auto &h : hists) total.merge(h);
  auto us = [](uint64_t ns) { return double(ns) / 1e3; };
  std::time_t st = system_clock::to_time_t(started);
  char stamp[32]; std::strftime(stamp, sizeof stamp, "%Y-%m-%dT%H:%M:%SZ", std::gmtime(&st));
  char line[2048];
  std::snprintf(line, sizeof line,
    "{\"impl\":\"cpp-cache\",\"version\":\"%s\",\"scenario\":\"%s\",\"keys\":%d,\"workers\":%d,\"capacity\":%d,"
    "\"ttl_ms\":%.3f,\"solver_latency_us\":%.3f,\"warmup_s\":%.3f,\"duration_s\":%.6f,\"requests\":%llu,"
    "\"throughput_rps\":%.3f,\"mean_us\":%.3f,\"p50_us\":%.3f,\"p90_us\":%.3f,\"p99_us\":%.3f,\"p999_us\":%.3f,"
    "\"max_us\":%.3f,\"solver_calls\":%llu,\"solver_mean_us\":%.3f,\"hits\":%llu,\"misses\":%llu,\"errors\":%llu,\"rss_mb\":%.3f,"
    "\"runtime\":\"%s\",\"max_procs\":%u,\"started_at\":\"%s\"}",
    CACHEBENCH_VERSION, scenario.c_str(), keys, workers, capacity,
    double(ttl_us) / 1e3, double(solver_us), double(warmup_us) / 1e6, elapsed, (unsigned long long) total.count,
    double(total.count) / elapsed, us(total.sum) / double(std::max<uint64_t>(total.count, 1)),
    us(total.percentile(0.50)), us(total.percentile(0.90)), us(total.percentile(0.99)), us(total.percentile(0.999)),
    us(total.max), (unsigned long long) (calls1 - calls0), solver_mean_us, (unsigned long long) (s1.hits - s0.hits),
    (unsigned long long) (s1.misses - s0.misses), (unsigned long long) errors.load(), rss_mb(),
    __VERSION__, std::thread::hardware_concurrency(), stamp);
  if (out.empty()) { std::puts(line); return 0; }
  std::ofstream f(out, std::ios::app);
  f << line << "\n";
  std::fprintf(stderr, "%s workers=%d rps=%.0f p50=%.1fus p99=%.1fus solver_calls=%llu hits=%llu misses=%llu\n",
               scenario.c_str(), workers, double(total.count) / elapsed, us(total.percentile(0.5)), us(total.percentile(0.99)),
               (unsigned long long) (calls1 - calls0), (unsigned long long) (s1.hits - s0.hits), (unsigned long long) (s1.misses - s0.misses));
  return 0;
}
