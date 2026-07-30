import json
import os
import re
import subprocess
from pathlib import Path

from flask import Flask, jsonify, render_template

try:
    from dotenv import load_dotenv
except ImportError:  # pragma: no cover - fallback for minimal environments
    def load_dotenv(*args, **kwargs):
        return False

BASE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = BASE_DIR.parent
CONFIG_PATH = BASE_DIR / "config" / "servers.json"

load_dotenv(BASE_DIR / ".env")

app = Flask(__name__, template_folder="templates", static_folder="static")


def load_servers():
    with CONFIG_PATH.open("r", encoding="utf-8") as handle:
        servers = json.load(handle)
    return servers


def get_server(server_id):
    for server in load_servers():
        if server.get("id") == server_id:
            return server
    return None


def resolve_compose_path(server):
    compose_project = server.get("compose_project")
    if not compose_project:
        return None

    path = Path(compose_project)
    if not path.is_absolute():
        path = PROJECT_ROOT / path

    if path.is_dir():
        return path / "compose.yaml"
    return path


def get_compose_service_names(compose_file):
    if not compose_file or not Path(compose_file).exists():
        return []

    services = []
    in_services = False
    for line in Path(compose_file).read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        if not in_services:
            if stripped == "services:":
                in_services = True
            continue

        if not line.startswith("  "):
            break

        if line.startswith("    "):
            continue

        if stripped.endswith(":"):
            services.append(stripped[:-1])

    return services


def resolve_service_name(server):
    configured_name = server.get("service_name")
    compose_file = resolve_compose_path(server)
    compose_services = get_compose_service_names(compose_file)

    if configured_name and configured_name in compose_services:
        return configured_name
    if compose_services:
        return compose_services[0]
    return configured_name or server.get("id")


def run_compose_command(server, *args):
    compose_file = resolve_compose_path(server)
    if not compose_file:
        raise ValueError("No compose project configured")

    command = ["docker", "compose", "-f", str(compose_file), *args]
    return subprocess.run(
        command,
        capture_output=True,
        text=True,
        check=False,
        cwd=str(PROJECT_ROOT),
    )


def get_server_status(server):
    try:
        result = run_compose_command(server, "ps")
    except (ValueError, FileNotFoundError):
        return "unknown"

    output = f"{result.stdout}\n{result.stderr}".lower()
    if re.search(r"\b(up|running|healthy)\b", output):
        return "running"
    if re.search(r"\b(exited|stopped|dead|created|restarting)\b", output):
        return "stopped"
    return "unknown"


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/servers")
def api_servers():
    servers = []
    for server in load_servers():
        servers.append(
            {
                "id": server.get("id"),
                "name": server.get("name"),
                "description": server.get("description", ""),
                "port": server.get("port"),
                "status": get_server_status(server),
            }
        )
    return jsonify(servers)


@app.route("/api/start/<server_id>", methods=["POST"])
def api_start(server_id):
    server = get_server(server_id)
    if server is None:
        return jsonify({"success": False, "message": "Server not found"}), 404

    service_name = resolve_service_name(server)

    try:
        result = run_compose_command(server, "up", "-d", service_name)
    except (ValueError, FileNotFoundError) as exc:
        return jsonify({"success": False, "message": str(exc)}), 500

    if result.returncode != 0:
        return jsonify(
            {
                "success": False,
                "message": result.stderr.strip() or result.stdout.strip() or "Start failed",
            }
        ), 500

    return jsonify({"success": True, "message": "Server started", "status": get_server_status(server)})


@app.route("/api/stop/<server_id>", methods=["POST"])
def api_stop(server_id):
    server = get_server(server_id)
    if server is None:
        return jsonify({"success": False, "message": "Server not found"}), 404

    service_name = resolve_service_name(server)

    try:
        result = run_compose_command(server, "stop", service_name)
    except (ValueError, FileNotFoundError) as exc:
        return jsonify({"success": False, "message": str(exc)}), 500

    if result.returncode != 0:
        return jsonify(
            {
                "success": False,
                "message": result.stderr.strip() or result.stdout.strip() or "Stop failed",
            }
        ), 500

    return jsonify({"success": True, "message": "Server stopped", "status": get_server_status(server)})


@app.route("/api/status/<server_id>")
def api_status(server_id):
    server = get_server(server_id)
    if server is None:
        return jsonify({"success": False, "message": "Server not found"}), 404

    return jsonify({"id": server.get("id"), "status": get_server_status(server)})


def main():
    host = os.getenv("FLASK_HOST", "127.0.0.1")
    port = int(os.getenv("FLASK_PORT", "5000"))
    debug = os.getenv("FLASK_DEBUG", "").strip().lower() in {"1", "true", "yes", "on"}
    app.run(host=host, port=port, debug=debug, use_reloader=False)


if __name__ == "__main__":
    main()
