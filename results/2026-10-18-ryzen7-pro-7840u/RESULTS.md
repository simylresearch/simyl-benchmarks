# Results — 2026-10-18-ryzen7-pro-7840u

- CPU: AMD Ryzen 7 PRO 7840U w/ Radeon 780M Graphics (8 cores, 16 threads, L3 16 MiB (1 instance)); memory 61348416 kB; Ubuntu 24.04.5 LTS, kernel 6.8.0-146-generic.
- Power: driver amd-pstate-epp, governor powersave, EPP balance_performance, platform profile balanced, boost None, AC 1.
- Toolchain: go version go1.24.4 linux/amd64; c++ (GCC) 13.2.0; cmake version 3.28.3.
- Sources: gateway_cache github.com/geniussportsgroup/gateway_cache/v3 v3.1.0; cpp-cache 5bfaf38; Aleph-w d37658b; harness 2614b33.
- Protocol: each cell is the median of 3 runs of 10 s (cold-herd: 3 s) after a warm-up; percentiles come from a log-linear histogram (≈6 % resolution); throughput shows min–max across runs. Total wall time 501 s.

## cold-herd

| impl | workers | req/s (median) | min–max | p50 µs | p99 µs | p99.9 µs | max µs | solver calls | solver mean µs | hits | misses | RSS MB |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cpp-cache | 64 | 3,011,286 | 2,888,972–3,043,999 | 2.9 | 188 | 655 | 50,861 | 100 | 50,060 | 9,040,958 | 100 | 21.5 |
| gateway_cache | 64 | 2,548,668 | 2,538,227–2,597,707 | 0.3 | 410 | 819 | 50,896 | 100 | 50,302 | 7,646,282 | 100 | 69.8 |

## eviction-churn

| impl | workers | req/s (median) | min–max | p50 µs | p99 µs | p99.9 µs | max µs | solver calls | solver mean µs | hits | misses | RSS MB |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cpp-cache | 16 | 19,616 | 19,616–19,623 | 1,049 | 1,049 | 1,114 | 4,808 | 150,875 | 1,058 | 45,300 | 150,891 | 24.0 |
| gateway_cache | 16 | 18,811 | 18,706–18,838 | 1,049 | 1,180 | 2,032 | 4,300 | 144,582 | 1,101 | 43,537 | 144,582 | 52.3 |

## hits-throughput

| impl | workers | req/s (median) | min–max | p50 µs | p99 µs | p99.9 µs | max µs | solver calls | solver mean µs | hits | misses | RSS MB |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cpp-cache | 1 | 3,729,630 | 3,525,642–3,767,226 | 0.1 | 0.9 | 2.3 | 304 | 0.0 | 0.0 | 37,296,675 | 0.0 | 51.4 |
| gateway_cache | 1 | 1,825,178 | 1,808,629–1,933,327 | 0.4 | 1.9 | 4.1 | 1,716 | 0.0 | 0.0 | 18,251,934 | 0.0 | 122 |
| cpp-cache | 4 | 2,074,345 | 1,846,801–2,149,483 | 0.6 | 13.8 | 28.7 | 4,050 | 0.0 | 0.0 | 20,743,613 | 0.0 | 51.5 |
| gateway_cache | 4 | 1,628,152 | 1,530,965–1,696,679 | 0.5 | 65.5 | 139 | 7,368 | 0.0 | 0.0 | 16,281,602 | 0.0 | 138 |
| cpp-cache | 8 | 2,145,859 | 1,827,492–2,265,028 | 1.8 | 21.5 | 45.1 | 6,076 | 0.0 | 0.0 | 21,458,746 | 0.0 | 51.6 |
| gateway_cache | 8 | 1,673,045 | 1,594,018–1,677,353 | 0.5 | 139 | 279 | 3,928 | 0.0 | 0.0 | 16,730,510 | 0.0 | 140 |
| cpp-cache | 16 | 1,907,896 | 1,786,557–2,120,210 | 3.6 | 53.2 | 115 | 8,290 | 0.0 | 0.0 | 19,079,125 | 0.0 | 51.7 |
| gateway_cache | 16 | 1,673,797 | 1,540,942–1,682,224 | 0.4 | 279 | 557 | 4,620 | 0.0 | 0.0 | 16,738,009 | 0.0 | 154 |

## hot-cold-ttl

| impl | workers | req/s (median) | min–max | p50 µs | p99 µs | p99.9 µs | max µs | solver calls | solver mean µs | hits | misses | RSS MB |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cpp-cache | 16 | 24,060 | 24,041–24,097 | 0.9 | 2,032 | 2,097 | 6,016 | 77,415 | 2,061 | 163,190 | 77,431 | 42.2 |
| gateway_cache | 16 | 21,866 | 21,770–21,867 | 2.7 | 2,228 | 2,621 | 5,047 | 71,842 | 2,208 | 146,826 | 71,842 | 71.8 |
