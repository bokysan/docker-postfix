#!/usr/bin/env bats

load /code/image_root/scripts/common.sh
load /code/image_root/scripts/functions.sh

declare temporary_file
setup() {
    temporary_file="$(mktemp -t)"
    cp /etc/postfix/main.cf "${temporary_file}"
}

teardown() {
    cat "${temporary_file}" > /etc/postfix/main.cf
    rm -rf "${temporary_file}"
}

@test "verify reading empty property" {
    local value

    do_postconf -e "mydestination="

    value="$(get_postconf "mydestination")"
    if [[ -n "${value}" ]]; then
        echo "Expected '', got: '$value' for 'mydestination'" >&2
        exit 1
    fi
}

@test "verify reading full property" {
    do_postconf -e 'mydestination=$myhostname, localhost.$mydomain $mydomain'

    value="$(get_postconf "mydestination")"
    if [[ "${value}" != '$myhostname, localhost.$mydomain $mydomain' ]]; then
        echo "Expected '\$myhostname, localhost.\$mydomain \$mydomain', got: '$value' for mydestination" >&2
        exit 1
    fi
}
