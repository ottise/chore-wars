# Local AI setup

The Flutter development app connects to the local backend at `http://localhost:5297`.

Run only one backend on port 5297. From the repository root, use `dotnet run --project backend/src/Presentation/Presentation.csproj --launch-profile http`; from the `backend` directory, use `dotnet run --project src/Presentation/Presentation.csproj --launch-profile http`. Stop the previous instance with Ctrl+C before starting another. A manually launched development server and a background preview server use the same port; running both causes a bind failure. During an ordinary shutdown, workers handle cancellation and disposed scopes without reporting them as background-service faults. Genuine work failures remain logged.
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

Assistant uses server configuration for private on-demand requests. It does not
require the household background-analysis switch. AI configuration, model status,
learning reports and evaluation dashboards are not exposed in the app. Legacy AI
settings/evaluation links redirect to Assistant and do not load internal reports.

Household background analysis remains separately controlled by `HouseAiSettings`;
automatic chat analysis additionally requires individual consent. Private Assistant
requests do not enable either switch or grant consent. Keep operational configuration
in the backend environment; never automatically opt users into chat analysis.

The existing telemetry worker and trainer continue processing background jobs.
Evaluation results remain in backend storage and are not loaded by user pages.
The owner-authorized operational APIs retain their existing authorization checks.

A 403 from `GET /api/houses/{id}/ai/chat/insights` can indicate missing chat-analysis
consent or inactive membership; it is not a Gemini health check. Private Assistant
uses `POST /api/houses/{id}/ai/interpret` and does not fetch chat insights or settings.

The Docker backend on port 8081 is a separate runtime. To use it with AI, start it
with both `docker-compose.yml` and `docker-compose.ai.yml`; its internal AI URL is
`http://ai-api:8000`, rather than the host loopback URL.

## Development media storage

The Development backend stores private chat media under
`backend/src/Presentation/.local-data/private-media`, resolved against the server's
content root. This directory is ignored by Git and survives switching between
Debug and Release builds. Deployment-specific absolute `MediaStorage:RootPath`
values continue to take precedence.

For existing local data, copy files from the old `bin/Debug/net10.0/private-media`
and `bin/Release/net10.0/private-media` directories into this stable directory.
Preserve originals and compare hashes before handling any filename collision;
never overwrite different bytes under an existing storage key. No database IDs,
room membership or download authorization need to change.
