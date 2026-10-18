#!/usr/bin/env bash
# Prints the measurement environment as JSON (hardware, OS, power settings, toolchains, pinned sources).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
python3 - "$ROOT" <<'PY'
import json, re, subprocess, sys, pathlib, datetime
root = pathlib.Path(sys.argv[1])
def sh(cmd):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30).stdout.strip()
    except Exception as e:
        return f"error: {e}"
def read(p):
    try:
        return pathlib.Path(p).read_text().strip()
    except OSError:
        return None
lscpu = {}
for line in sh("lscpu").splitlines():
    if ":" in line:
        k, v = line.split(":", 1); lscpu[k.strip()] = v.strip()
mem = {}
for line in read("/proc/meminfo").splitlines():
    k, v = line.split(":", 1); mem[k] = v.strip()
osr = dict(re.findall(r'^(\w+)="?([^"\n]*)"?$', read("/etc/os-release") or "", re.M))
cmake = root / "cpp" / "CMakeLists.txt"
pins = dict(re.findall(r'set\((\w+_COMMIT)\s+"([0-9a-f]+)"\)', cmake.read_text()))
env = {
  "captured_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
  "cpu": {"model": lscpu.get("Model name"), "sockets": lscpu.get("Socket(s)"), "cores_per_socket": lscpu.get("Core(s) per socket"),
          "threads_per_core": lscpu.get("Thread(s) per core"), "cpus": lscpu.get("CPU(s)"), "max_mhz": lscpu.get("CPU max MHz"),
          "min_mhz": lscpu.get("CPU min MHz"), "l2": lscpu.get("L2 cache"), "l3": lscpu.get("L3 cache"), "flags_have_avx2": "avx2" in lscpu.get("Flags", "")},
  "memory": {"total": mem.get("MemTotal"), "available_at_capture": mem.get("MemAvailable")},
  "os": {"name": osr.get("PRETTY_NAME"), "kernel": sh("uname -r"), "arch": sh("uname -m")},
  "power": {"scaling_driver": read("/sys/devices/system/cpu/cpu0/cpufreq/scaling_driver"),
            "governor": read("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"),
            "energy_performance_preference": read("/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference"),
            "platform_profile": read("/sys/firmware/acpi/platform_profile"),
            "boost": read("/sys/devices/system/cpu/cpufreq/boost"),
            "ac_online": read("/sys/class/power_supply/AC/online") or read("/sys/class/power_supply/ACAD/online"),
            "chassis": read("/sys/class/dmi/id/chassis_type")},
  "toolchain": {"go": sh(f"cd {root}/go && go version"), "cxx": sh("c++ --version | head -1"), "cmake": sh("cmake --version | head -1"), "python": sh("python3 --version")},
  "sources": {"gateway_cache": "github.com/geniussportsgroup/gateway_cache/v3 v3.1.0", **pins,
              "simyl_benchmarks_commit": sh(f"git -C {root} rev-parse --short HEAD 2>/dev/null || echo uncommitted")},
  "load_at_capture": read("/proc/loadavg"),
}
print(json.dumps(env, indent=2, ensure_ascii=False))
PY
