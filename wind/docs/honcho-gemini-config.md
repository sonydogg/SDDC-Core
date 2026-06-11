# Honcho General Config & Gemini Dependency

## Stack location & control
- Compose project: `/opt/honcho` (`docker compose ps|logs|up -d ...`)
- Config files:
  - `/opt/honcho/.env` — runtime config (LLM transport/model selection, API keys,
    embedding settings)
  - `~/.hermes/honcho.json` — Hermes-side wiring (workspace, peer mapping,
    recall/dialectic settings — see `honcho-integration.md`)

## Why Gemini
Background LLM work (deriver representation extraction, dialectic
synthesis, summary generation) is routed through **Google Gemini Flash**
rather than Anthropic models. Rationale: keeps the (high-volume, low-stakes)
background memory-processing load on a separate billing account from the
Anthropic spend that powers the actual agent conversations. Gemini Plus
subscription funds this.

## Where Gemini is wired in (`.env`)
Four config keys point at a Gemini model — **all four must be kept in sync**
when changing models:
```
DERIVER_MODEL_CONFIG__TRANSPORT=gemini
DERIVER_MODEL_CONFIG__MODEL=<model-id>
DIALECTIC_LEVELS__minimal__MODEL_CONFIG__TRANSPORT=gemini
DIALECTIC_LEVELS__minimal__MODEL_CONFIG__MODEL=<model-id>
DIALECTIC_LEVELS__low__MODEL_CONFIG__TRANSPORT=gemini
DIALECTIC_LEVELS__low__MODEL_CONFIG__MODEL=<model-id>
SUMMARY_MODEL_CONFIG__TRANSPORT=gemini
SUMMARY_MODEL_CONFIG__MODEL=<model-id>
```
Auth: `LLM_GEMINI_API_KEY` (also referenced as `GOOGLE_API_KEY` in some code
paths — same value).

Current value (post-incident): **`gemini-flash-latest`** — a rolling alias
maintained by Google that always points at their current-gen flash model.
Chosen deliberately over a pinned version string (e.g. `gemini-2.5-flash`) to
avoid repeating the incident below. Trade-off: behavior can shift slightly
when Google rolls the alias forward; acceptable for background memory
processing where consistency matters less than uptime.

## Incident: Gemini 2.0 Flash deprecation (2026-06-08)

**Symptom:** Honcho portal showing errors; `api` and `deriver` containers
spamming `RetryError[ClientError]` / `404 NOT_FOUND`.

**Root cause:** Google deprecated `models/gemini-2.0-flash` outright —
`This model is no longer available. Please update your code to use a newer
model.` It was hardcoded across all four `.env` keys above. Every deriver
batch and every dialectic query was retrying 3x and failing — representation
extraction stalled and dialectic answers degraded to empty/fallback.

**Fix:**
1. Pulled the live model list from `https://generativelanguage.googleapis.com/v1beta/models?key=<key>`
   to confirm what's still available (`gemini-2.5-flash`, `gemini-flash-latest`,
   `gemini-3-flash-preview`, etc. — `2.0-flash` confirmed gone).
2. Replaced all four `*_MODEL` values in `/opt/honcho/.env`:
   `gemini-2.0-flash` → `gemini-flash-latest`.
3. Recreated the affected containers:
   `cd /opt/honcho && docker compose up -d --force-recreate api deriver`
   (no need to touch `database`/`redis` — they don't read `.env` LLM config).
4. Verified with a live `honcho_reasoning` query — correctly synthesized an
   answer pulling from stored SDDC-Core context. Confirmed working.

**Action items / lessons:**
- Pin to Google's `-latest` rolling aliases for background/non-critical model
  selection rather than dated version strings — trades a small amount of
  behavioral drift for immunity to abrupt deprecation.
- **Preventive automation:** monthly cron watchdog
  `Gemini Model Deprecation Watchdog (Honcho)` —
  `~/.hermes/scripts/gemini_model_check.sh`, runs 1st of month @ 09:00 UTC,
  `no_agent` mode (pure script, silent on success, zero token cost). Diffs
  every `*_MODEL` value in `.env` against the live `/v1beta/models` list and
  raises an alert with the exact remediation steps if anything has vanished.
  This closes the loop — next deprecation gets caught before it shows up as
  user-facing portal errors.

## Quick health check
```bash
cd /opt/honcho
docker compose ps                                   # all 4 services healthy?
docker compose logs api deriver --since 1h | grep -iE "error|404|exception"
curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=$LLM_GEMINI_API_KEY" \
  | grep -o '"models/gemini-flash-latest"'          # confirm configured model still resolves
```
