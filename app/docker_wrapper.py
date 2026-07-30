"""Small docker wrapper: validates docker/compose availability.

Provides a helper to ensure the environment can run docker compose commands.
"""
import shutil
import subprocess


def ensure_docker_available():
    """Raise FileNotFoundError if neither `docker compose` nor `docker-compose` is usable.

    Prefer the modern `docker compose` subcommand when available, fall back to
    legacy `docker-compose` if present.
    """
    docker_bin = shutil.which("docker")
    docker_compose_bin = shutil.which("docker-compose")

    if docker_bin is None and docker_compose_bin is None:
        raise FileNotFoundError("Neither 'docker' nor 'docker-compose' found in PATH")

    # If docker exists, check whether `docker compose` is supported. If not,
    # require docker-compose to be present.
    if docker_bin:
        try:
            result = subprocess.run(["docker", "compose", "version"], capture_output=True, text=True)
            if result.returncode == 0:
                return
        except FileNotFoundError:
            pass

    if docker_compose_bin:
        return

    # If we get here, there was a docker binary but `docker compose` failed and
    # no docker-compose fallback is available.
    raise FileNotFoundError("'docker compose' not available and 'docker-compose' not found")
