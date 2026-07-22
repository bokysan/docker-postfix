#!/bin/sh
# Run `act` against whatever container engine is available.
#
# Prefers podman (rootful or rootless), falls back to docker, and adjusts the
# container options so that bind-mounting the engine socket into the runner
# container actually works. See the notes inline for the why.
set -eu

log() { printf 'act.sh: %s\n' "$*" >&2; }

ENGINE=""
CONTAINER_OPTS=""      # value for --container-options (empty => omit)
DAEMON_SOCKET=""       # value for --container-daemon-socket (empty => act default)
rootful="n/a"

configure_podman() {
    ENGINE=podman

    # Pick the running machine, else the default one, else none (native Linux).
    machine="$(podman machine list --format '{{.Name}}|{{.Running}}|{{.Default}}' 2>/dev/null \
        | awk -F'|' '$2=="true"{print $1; f=1; exit} $3=="true"{d=$1} END{if(!f && d) print d}')"

    if [ -n "$machine" ]; then
        # macOS / Windows: podman runs inside a VM, so there are two socket
        # namespaces. act talks to podman over the host-side machine socket,
        # but the socket bind-mounted INTO the runner must be the in-VM path.
        rootful="$(podman machine inspect "$machine" --format '{{.Rootful}}' 2>/dev/null || echo false)"

        if [ -S /var/run/docker.sock ]; then
            # The podman-machine docker-compat symlink works for both act (host
            # side) and the in-container mount (it resolves inside the VM), so
            # leave the socket defaults untouched.
            :
        else
            host_sock="$(podman machine inspect "$machine" --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null || true)"
            vm_sock="$(podman info --format '{{.Host.RemoteSocket.Path}}' 2>/dev/null | sed 's#^unix://##')"
            [ -n "$host_sock" ] && export DOCKER_HOST="unix://$host_sock"
            [ -n "$vm_sock" ]   && DAEMON_SOCKET="unix://$vm_sock"
        fi
    else
        # Native Linux podman: one namespace, the reported socket works directly
        # for both connecting and bind-mounting.
        sock="$(podman info --format '{{.Host.RemoteSocket.Path}}' 2>/dev/null | sed 's#^unix://##')"
        [ -n "$sock" ] && export DOCKER_HOST="unix://$sock"
        case "$sock" in
            */run/user/*) rootful=false ;;
            *) [ "$(id -u)" -eq 0 ] && rootful=true || rootful=false ;;
        esac
    fi

    # The runner container gets the engine socket bind-mounted in. Two things
    # can block access to it from inside the container:
    #   * a rootful socket is root-owned    -> run the container as root
    #   * the podman VM enforces SELinux     -> drop the container's SELinux
    #     label (a harmless no-op when SELinux is not enabled)
    CONTAINER_OPTS="--security-opt label=disable"
    [ "$rootful" = "true" ] && CONTAINER_OPTS="--user 0 $CONTAINER_OPTS"
}

configure_docker() {
    ENGINE=docker
    # Docker (Desktop or engine) resolves its socket via the active context and
    # mounts an accessible socket into containers, so no extra options are
    # needed here.
    CONTAINER_OPTS=""
}

if command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
    configure_podman
elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    configure_docker
else
    log "no working podman or docker engine found"
    exit 1
fi

log "engine=$ENGINE rootful=$rootful${DOCKER_HOST:+ DOCKER_HOST=$DOCKER_HOST}${CONTAINER_OPTS:+ container-options='$CONTAINER_OPTS'}"

# Some steps (e.g. the ghcr login, or any authenticated checkout) use a
# GITHUB_TOKEN, which GitHub injects automatically but act does not. Prefer an
# explicit env var, else borrow the gh CLI's token when it is authenticated.
# It is optional — the build works without it for public, push-less local runs.
: "${GITHUB_TOKEN:=}"
if [ -z "$GITHUB_TOKEN" ] && command -v gh >/dev/null 2>&1; then
    GITHUB_TOKEN="$(gh auth token 2>/dev/null || true)"
fi

# Assemble the act command line. --container-architecture is needed on Apple
# Silicon so the amd64 runner image is emulated.
set -- --container-architecture linux/amd64 "$@"
[ -n "$CONTAINER_OPTS" ] && set -- --container-options "$CONTAINER_OPTS" "$@"
[ -n "$DAEMON_SOCKET" ]  && set -- --container-daemon-socket "$DAEMON_SOCKET" "$@"
if [ -n "$GITHUB_TOKEN" ]; then
    set -- --secret "GITHUB_TOKEN=$GITHUB_TOKEN" "$@"
else
    log "no GITHUB_TOKEN found (optional; needed only for authenticated checkout/registry login — run 'gh auth login' or export GITHUB_TOKEN)"
fi

exec act "$@"
