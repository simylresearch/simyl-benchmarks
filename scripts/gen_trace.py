#!/usr/bin/env python3
"""Generate a deterministic request trace: N key indices in [0, keys) drawn from a
Zipf distribution with exponent s (probability of rank r proportional to 1/(r+1)^s).
The file holds little-endian uint32 values and is replayed identically by every
implementation, so all of them see the same request sequence."""
import argparse
import random
from array import array
from pathlib import Path

ap = argparse.ArgumentParser()
ap.add_argument("--keys", type=int, required=True)
ap.add_argument("--requests", type=int, required=True)
ap.add_argument("--zipf", type=float, default=1.0, help="exponent s; 0 = uniform")
ap.add_argument("--seed", type=int, default=20261018)
ap.add_argument("--out", required=True)
a = ap.parse_args()

rng = random.Random(a.seed)
cum, acc = [], 0.0
for r in range(a.keys):
    acc += 1.0 / ((r + 1) ** a.zipf)
    cum.append(acc)
draws = rng.choices(range(a.keys), cum_weights=cum, k=a.requests)
Path(a.out).parent.mkdir(parents=True, exist_ok=True)
with open(a.out, "wb") as f:
    array("I", draws).tofile(f)
distinct = len(set(draws))
top = draws.count(0) / a.requests
print(f"{a.out}: {a.requests} requests over {a.keys} keys, zipf={a.zipf}, seed={a.seed}, distinct={distinct}, top-key share={top:.3%}")
