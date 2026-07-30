# Copilot instructions for this repository

This repository manages local Minecraft servers with Docker Compose and a lightweight Flask web app.

## Project context
- Server definitions live under the servers/ directory, with each server having its own compose.yaml and data/ folder.
- The web control panel entry point is app/app.py.
- Server metadata for the UI is stored in app/config/servers.json.
- Local runtime settings belong in app/.env (do not commit secrets or environment-specific values).
- Required python libraries are installed into a virtual environment under the project root folder (.venv/).

## Working conventions
- Keep changes small and focused.
- Preserve existing server IDs, compose paths, and service names unless a change explicitly requires otherwise.
- Avoid editing world data or server runtime files unless the request clearly calls for it.
- Prefer the existing Flask and template patterns already used in app/.

## Validation
- If you change app behavior, run:
  - pytest -q tests/test_app.py
- If you modify Docker-related configuration, verify the relevant compose file and server directory still look correct.

## Safety
- Do not commit secrets, tokens, or local-only environment values.
- Be cautious when touching files under servers/*/data/ because they contain live server state.
