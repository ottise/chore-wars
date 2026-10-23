# Local AI setup

The Flutter development app connects to the local backend at `http://localhost:5297`.
The AI API runs in Docker and is published only on `127.0.0.1:8011`.

Keep `GEMINI_API_KEY`, `AI_SERVICE_KEY` and `AI_POSTGRES_PASSWORD` in the Git-ignored
`.env.ai.local` file. The internal service key must have at least 32 characters.
Never copy these values into tracked configuration files.

From the repository root, run:

```powershell
.\backend\scripts\start-ai-local.ps1
```

This starts the AI API, migrations, dedicated database, worker and trainer. It writes
the local backend connection into the Git-ignored
`backend/src/Presentation/appsettings.AI.local.json`. The backend reads this file
only in Development; environment variables and command-line arguments retain priority.
Restart the local backend after changing its AI configuration.

Check `http://127.0.0.1:8011/health/ready`: `status` must be `ready` and
`provider_configured` must be `true`. This checks database readiness and the presence
of a provider key; a successful interpretation request is needed to verify inference.

In the app, the owner enables Assistant in AI Settings for each household.
Automatic analysis of household chat remains a separate opt-in with individual consent.
Private on-demand assistant requests do not enable automatic chat analysis.

The Docker backend on port 8081 is a separate runtime. To use it with AI, start it
with both `docker-compose.yml` and `docker-compose.ai.yml`; its internal AI URL is
`http://ai-api:8000`, rather than the host loopback URL.
