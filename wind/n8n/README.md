# n8n Workflows

JSON source files for n8n workflows. Changes pushed to `main` are automatically deployed to the n8n instance via GitHub Actions.

## Deployment

The [deploy-n8n](.github/workflows/deploy-n8n.yml) Action triggers on any push to `wind/n8n/*.json` on `main`. It reads the `id` field from each changed file and calls the n8n REST API to update the workflow.

**Required GitHub Secrets:**
| Secret | Value |
|--------|-------|
| `N8N_API_KEY` | n8n → Settings → API → Create API Key |
| `N8N_BASE_URL` | Your Cloudflare tunnel URL (no trailing slash) |

## Workflows

| File | Workflow ID | Description |
|------|-------------|-------------|
| `manage-jira-tickets.json` | `2aptMbMcurbztVDO` | Claude PM agent — create, update, transition, comment on Jira tickets via MCP |
| `smart-documentation.json` | `gRCCOeYcghGyiaOS` | GitHub push → Markdown → Confluence sync for ADRs |

## Adding a New Workflow

1. Export JSON from n8n (workflow menu → Download)
2. Ensure the JSON has an `"id"` field matching the n8n workflow ID
3. Drop the file in `wind/n8n/`
4. Commit and push — the Action handles the rest
