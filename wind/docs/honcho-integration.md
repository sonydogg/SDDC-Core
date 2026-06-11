# Honcho Integration (Bert / Hermes Memory Layer)

## What it is
Honcho is a self-hosted persistent-memory backend for Hermes agent peers (Bert,
PM agent, etc.). It stores conversation history, derives long-term
"representations" of users/agents, and serves dialectic queries (synthesized
answers about a peer) back to the agent at runtime.

Self-hosted at `/opt/honcho` via Docker Compose — **not** the hosted SaaS.
Runs alongside the rest of the stack on the Intel Mini nodes.

## Architecture (local stack)
```
honcho-api-1        FastAPI app, serves Hermes via http://localhost:8000
honcho-deriver-1    Background worker — derives "observations"/representations
                    from raw conversation messages (async, queue-driven)
honcho-database-1   pgvector/pgvector:pg15 — Postgres + vector embeddings
honcho-redis-1      Redis — queue/cache backbone for the deriver
```
All four containers must report healthy. `docker compose ps` from `/opt/honcho`.

## Hermes-side wiring
Config: `~/.hermes/honcho.json`
- `baseUrl`: `http://localhost:8000`
- `workspace`: `hermes`
- Per-host overrides under `hosts`:
  - `hermes` → `aiPeer: bert`, `sessionStrategy: global`, `recallMode: hybrid`,
    `dialecticDepth: 2`, `dialecticReasoningLevel: low`
  - `hermes_pm` → `aiPeer: pm-agent`, `dialecticDepth: 1`,
    `dialecticReasoningLevel: minimal` (lighter footprint — PM agent doesn't
    need deep recall)

Memory provider for the Bert profile is set to `honcho` (vs. flat-file Hermes
memory). Memory limits raised to `memory_char_limit=5000`,
`user_char_limit=3000` to give Honcho's richer context model more room.

## Tools available to the agent
- `honcho_profile` — quick factual snapshot of a peer (cheap)
- `honcho_search` — raw semantic search over stored context (cheap, no LLM synthesis)
- `honcho_context` — raw session context dump (cheap)
- `honcho_reasoning` — synthesized answer via Honcho's own LLM (costlier; pass
  `reasoning_level`: minimal/low/medium/high/max)
- `honcho_conclude` — persist a factual conclusion about a peer (or delete for PII)

Prefer `profile`/`search`/`context` for cheap lookups; reach for `reasoning`
only when you need synthesis across multiple observations.

## Operational notes
- **LLM dependency:** Honcho's deriver and dialectic layers call out to an
  external LLM (currently Gemini — see `honcho-gemini-config.md` for the full
  dependency writeup and the Gemini deprecation incident from 2026-06-08).
  If that LLM call fails, the deriver queue backs up silently — no user-facing
  symptom until dialectic queries start returning empty/degraded answers.
- **Health check:** `cd /opt/honcho && docker compose ps` — all four services
  should show `healthy`/`Up`.
- **Logs:** `docker compose logs <service> --since <Nh> | grep -iE "error|exception"`
  — `api` and `deriver` are the ones that talk to the LLM and will surface
  upstream provider errors first.
- **Restart after config change:**
  `docker compose up -d --force-recreate api deriver`
  (database/redis don't need recreation for `.env`/model config changes).

## Known gotchas
- `Failed to prefetch observations: OpenAI API key is required` — cosmetic
  warning. Honcho's dialectic prefetch path optionally wants an OpenAI key for
  an auxiliary feature; gracefully degrades when absent. We're routing
  intentionally through Gemini to keep billing isolated from Anthropic — leave
  this as-is unless the feature becomes load-bearing.
- `Query exceeds maximum token limit of 8192` — embedding input limit
  (`settings.EMBEDDING.MAX_INPUT_TOKENS`). Caught gracefully, returns empty
  results and moves on. Seen during heavy/compound dialectic queries; not
  currently a recurring production issue, but if it shows up regularly it's a
  sign queries need to be scoped tighter or the embedding model's input window
  needs revisiting.

## Watchdog
A monthly cron job (`Gemini Model Deprecation Watchdog (Honcho)`,
`~/.hermes/scripts/gemini_model_check.sh`, runs 1st @ 09:00 UTC) diffs the
model IDs configured in `/opt/honcho/.env` against Google's live
`/v1beta/models` list and alerts if any have disappeared — see
`honcho-gemini-config.md` for why this exists.
