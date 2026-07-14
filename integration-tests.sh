#!/usr/bin/env bash
set -e

./build.sh --load --tag boky/postfix

FIND="$(which find)"

# Support running on macOS with GNU installed under "g*" prefix
if command -v gfind > /dev/null 2>&1; then
    FIND="$(which gfind)"
fi

if command -v docker >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
    if docker --help | grep -q -F 'compose*'; then
        DOCKER_COMPOSE="docker compose"
    fi
elif command -v podman >/dev/null 2>&1; then
    DOCKER_COMPOSE="podman compose"
else
    echo "Neither `docker` or `podman` installed. Cannot execute tests."
    exit 1
fi

run_test() {
    local exit_code
    local dir

    if [[ -f "$1" ]]; then
        dir="$(dirname "$1")"
    else
        dir="$1"
    fi

    echo
    echo
    echo "☆☆☆☆☆☆☆☆☆☆ $dir ☆☆☆☆☆☆☆☆☆☆"
    echo
    (
        cd "$dir"
        set +e
        $DOCKER_COMPOSE up --build --abort-on-container-exit --exit-code-from tests
        exit_code="$?"

        $DOCKER_COMPOSE down -v
        if [[ "$exit_code" != 0 ]]; then
            exit "$exit_code"
        fi
        set -e
    )
}

run_single_test() {
    if [[ -d "$1" ]]; then
        TEST="$($FIND "$1" -regextype posix-extended -regex '.*/(docker-)?compose\.ya?ml' -print -quit | head -n1)"
        if [[ -f "$TEST" ]]; then
            run_test "$TEST"
        else
            echo "Error: Can't find compose file in $1" >&2
            exit 2
        fi
    elif [[ -f "$1" ]]; then
        run_test "$1"
    elif [[ ! "$var" =~ ^integration-tests/ ]]; then
        run_single_test "integration-tests/$1"
    else
        echo "Error: Can't find test $1" >&2
        exit 2
    fi
}

if [[ $# -gt 0 ]]; then
    while [[ -n "$1" ]]; do
        run_single_test "$1"
        shift
    done
else
    cd integration-tests
    for i in `${FIND} -maxdepth 1 -type d | grep -Ev "^./(tester|xoauth2)" | sort`; do
        i="$(basename "$i")"
        if [ "$i" == "." ] || [ "$i" == ".." ]; then
            continue
        fi
        run_test $i
    done
fi
