# AI Token Control Plane

Make every LLM call in the firm **metered, routed, cached, compressed, governed, and priced by outcome** —
so AI scales without the cost scaling with it.

**This is a control plane, not a compressor.** Payload compression (e.g. [Headroom](https://github.com/chopratejas/headroom))
is *one pluggable stage*. The defensible layer — the part a vendor or OSS tool doesn't give you — is model
**routing**, budget **governance**, and **outcome pricing** tuned on your own telemetry.

> One gateway sits in front of every model call. That single chokepoint is what lets you
> *see* token spend, *cut* it (route to the cheapest model that still passes, reuse prior
> answers, compress the payload), *cap* it (kill runaway agents), and *price* it against business outcomes.

Pipeline: `governor → cache → router → compress → model → quality gate → meter/price`

## What's here

| File | What it is | Use it for |
|---|---|---|
| `control_plane_demo.html` | Self-contained visual simulator (vanilla JS, no deps) | **The stage demo.** Double-click to open in any browser. Runs offline. |
| `control_plane.py` | Core logic: router, semantic cache, budget governor, quality gate, metrics (stdlib only) | The "real engineering" proof |
| `gateway.py` | FastAPI OpenAI-compatible proxy + `/metrics` (sim mode by default) | Show it's production-shaped |
| `demo.py` | CLI: naive vs control-plane, plus the runaway kill-switch scenario | `python3 demo.py` or `.venv/bin/python demo.py` |

## Run the visual demo (no install)

Open `control_plane_demo.html` in a browser. Toggle Router / Cache / Governor, press
**Run agent**, watch calls flow through. Press **Run buggy agent** to see the kill switch fire.
Drag the fleet slider to project annual savings at JPM scale. All off = naive baseline.

## Run the Python demo (no install)

```bash
python3 demo.py
```

If you prefer a local virtualenv, or your machine has `python3` but not `python`:

```bash
python3 -m venv .venv
source .venv/bin/activate
python demo.py
```

## Run the gateway (optional)

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
uvicorn gateway:app --reload
curl -s localhost:8000/v1/chat/completions -H 'content-type: application/json' \
  -d '{"task":"codegen","agent_run_id":"run-1","prompt":"fix null currency NPE"}'
curl -s localhost:8000/metrics
```

## Run with Docker

```bash
docker compose up --build
#   gateway API -> http://localhost:8000   (/metrics, /v1/chat/completions)
#   visual demo -> http://localhost:8080
```

State is in-memory today. To match the reference architecture, uncomment the `redis` +
`postgres` services in `docker-compose.yml` and point the cache/governor/telemetry at them.

## Verified demo numbers (one agent resolving one ticket)

| | Naive (frontier-only) | Control plane | Δ |
|---|---|---|---|
| Tokens | 273,000 | 114,430 | −58% |
| Cost | $4.09 | $0.28 | −93% |
| Quality (Q) | 0.93 | 0.89 | held above bar |
| **Cost / resolved ticket** | **$4.38** | **$0.31** | **−93%** |

Each lever compounds (governor is a *safety* lever — it caps blast radius, shown separately):

| Stage | Cost | Cumulative cut |
|---|---|---|
| naive (frontier) | $4.09 | — |
| + semantic cache | $2.76 | −33% |
| + model routing | $0.42 | −90% |
| + payload compression | $0.28 | −93% |

Runaway scenario: a buggy agent looping on the same call is **killed after 3 retries** instead
of burning the full budget — that's the governor, the one lever that caps risk rather than cost.

## The pitch in one line

> Competitors can copy the AI. They can't copy a router tuned on our own engineering telemetry,
> or a governance layer that lets us deploy AI where they can't afford to.

## Going to production

- Swap simulated `run_model` / `call_backend` for real provider calls (LiteLLM, Bedrock, internal LLM Suite).
- Swap the Jaccard cache for real embeddings + ANN (pgvector / FAISS), cosine ≥ 0.95.
- Swap the modeled `compress_tokens` for a real compression adapter — **Headroom** is the reference fit
  (content-aware, local-first, reversible). The control plane owns routing/governance/pricing; the
  compressor is a transform it calls.
- Move cache/governor/telemetry state to Redis + Postgres.
- Replace the cold-start router rules with a learned policy updated by quality-gate outcomes — **this is the proprietary moat.**

## Why not just use a compression OSS tool?

Compression shrinks each payload. It does **not** pick the model, cap a runaway agent, or price by
outcome. Tools like Headroom are excellent on the compression axis and we plug them in — but routing,
governance, and outcome economics tuned on JPM's own SDLC telemetry are the parts no OSS tool ships,
and the parts that fit a centrally-governed, audited, sandboxed bank runtime.

*Prices illustrative: small $0.30 · mid $3.00 · frontier $15.00 per 1M tokens.*
