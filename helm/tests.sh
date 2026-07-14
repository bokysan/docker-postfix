#!/usr/bin/env bash
set -e

reset="$(printf '\033[0m')"
green="$(printf '\033[38;5;46m')"
yellow="$(printf '\033[38;5;178m')"
orange="$(printf '\033[38;5;208m')"
orange_emphasis="$(printf '\033[38;5;220m')"
lightblue="$(printf '\033[38;5;147m')"
red="$(printf '\033[91m')"
gray="$(printf '\033[38;5;245m')"
emphasis="$(printf '\033[38;5;111m')"
underline="$(printf '\033[4m')"

SCRIPT_DIR="$( pwd; )/$( dirname -- $0; )"
cd "${SCRIPT_DIR}"
FIND="find"

if command -v docker >/dev/null 2>&1; then
    DOCKER="docker"
elif command -v podman >/dev/null 2>&1; then
    DOCKER="podman"
else
    echo "Neither `docker` or `podman` installed. Cannot execute tests."
    exit 1
fi

mkdir -p fixtures
# Brew installs GNU find as "gfind" by default
if command -v gfind >/dev/null 2>&2; then
    FIND="$(which gfind)"
fi

do_the_test() {
    local i="${1}" v
    printf '%s' "${gray}☆☆☆☆☆☆☆☆☆☆${reset} ${orange_emphasis}$i${reset}: ${gray}☆☆☆☆☆☆☆☆☆☆${reset}"
    echo
    # Test only non-EOL versions
    for v in 1.33.13 1.34.9 1.36.2; do
        printf '%s' "${emphasis}${lightblue}k8s v${v}${reset}${lightblue}... ${reset}"
        helm template -f "${i}" --kube-version "${v}" --dry-run=client mail > fixtures/demo.yaml
        ${DOCKER} run \
            -v "${SCRIPT_DIR}/fixtures:/fixtures" \
            -v "${SCRIPT_DIR}/schemas:/schemas" \
            ghcr.io/yannh/kubeconform:latest-alpine \
                -summary -debug -kubernetes-version "${v}" \
                -cache "./schemas/cached" \
                -schema-location "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/{{ .NormalizedKubernetesVersion }}-standalone{{ .StrictSuffix }}/{{ .ResourceKind }}{{ .KindSuffix }}.json" \
                -schema-location "./schemas/master-standalone/{{ .ResourceKind }}{{ .KindSuffix }}.json" \
                fixtures/demo.yaml
    done
}


if [[ $# -gt 0 ]]; then
    while [[ $# -gt 0 ]]; do
        do_the_test "${1}"
        shift
    done
else
    for i in `${FIND} -maxdepth 1 -type f -name test\*yml | sort`; do
        do_the_test "${i}"
    done
fi