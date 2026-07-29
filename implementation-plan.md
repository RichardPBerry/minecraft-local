# Implementation Plan: Flask-based LAN Control Panel for Minecraft Containers

This document outlines a practical implementation plan for a lightweight Flask web app that can start and stop Docker containers for multiple Minecraft servers from devices on the local network.

## Goals
- Build a very simple web UI for local network access
- Use Flask for both the backend and the frontend serving layer
- Support multiple Minecraft server instances
- Keep the footprint small and easy to maintain
- Add basic security controls for LAN use

## Recommended stack
- Backend: Python + Flask
- Frontend: plain HTML/CSS/JavaScript served by Flask
- Container orchestration: Docker Compose
- Configuration: JSON manifest file
- Security: basic auth, environment variables, localhost binding by default

## Project structure
```text
minecraft-local/
    
    implementation-plan.md
    app/
        app.py
        requirements.txt
        templates/
            index.html
        static/
            styles.css
            app.js
        config/
            servers.json
        .env.example
    servers/
        configuration/
            ops-list.json
            rcon-password.txt
        survival-vanilla-001/
            compose.yaml
        creative-vanilla-002/
            compose.yaml
        survival-aitm10-003/
            compose.yaml
```

## Implementation steps

### 1. Create the Flask app
- Add a new folder named app/ at the project root
- Create a Flask entry point in app/app.py
- Use Flask routes for:
  - / for the main UI
  - /api/servers for listing available servers
  - /api/start/<server_id> for starting a server
  - /api/stop/<server_id> for stopping a server
  - /api/status/<server_id> for checking state

### 2. Add a simple UI
- Build a single-page interface with:
  - server list
  - status badge
  - Start/Stop buttons
  - simple log/result area
- Serve the HTML from Flask templates and CSS/JS from static files
- Keep the UI intentionally minimal and responsive

### 3. Define server inventory
- Add a JSON file such as app/config/servers.json
- Each server entry should include:
  - id
  - name
  - compose_project
  - service_name
  - description
  - port
- Initially, this will include the current Minecraft server entry

### 4. Integrate Docker control
- Use Python subprocess calls to run Docker commands such as:
  - docker compose -f <compose_file> ps
  - docker compose -f <compose_file> up -d <service>
  - docker compose -f <compose_file> stop <service>
- Keep the implementation focused on the current compose workflow
- For future expansion, support multiple compose files or projects

### 5. Add basic security
- Bind the Flask app to 0.0.0.0 only if needed for LAN access
- Prefer binding to 127.0.0.1 by default
- Add simple authentication via environment variables:
  - FLASK_USERNAME
  - FLASK_PASSWORD
- Use a secret key from environment variables
- Do not commit secrets to the repository

### 6. Add environment and dependency files
- Create requirements.txt with:
  - Flask
  - python-dotenv
- Add .env.example with placeholders for:
  - FLASK_USERNAME
  - FLASK_PASSWORD
  - FLASK_SECRET_KEY
  - FLASK_HOST
  - FLASK_PORT


## Suggested backend routes
```python
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/servers')
def api_servers():
    ...

@app.route('/api/start/<server_id>', methods=['POST'])
def api_start(server_id):
    ...

@app.route('/api/stop/<server_id>', methods=['POST'])
def api_stop(server_id):
    ...

@app.route('/api/status/<server_id>')
def api_status(server_id):
    ...
```

## Suggested UI behavior
- Load the list of servers on page load
- Show a button for Start or Stop depending on current state
- Refresh state every 10–15 seconds
- Display errors clearly if Docker commands fail

## Security notes
- Do not expose the app to the internet by default
- Use a firewall or reverse proxy if you want LAN access beyond a trusted network
- Consider adding HTTPS later if the panel will be used outside a private network
- Avoid running the app as root

## Rollout plan
1. Create the Flask app structure and configuration files
2. Implement the server inventory and Docker command wrapper
3. Add the web UI and API routes
4. Test locally with one server
5. Add authentication and host binding options
6. Document usage in the main README

## Expected result
A lightweight Flask-based control panel will be available that can list Minecraft servers and start or stop them from a simple browser interface on the local network.
