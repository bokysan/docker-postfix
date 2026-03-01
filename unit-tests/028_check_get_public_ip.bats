#!/usr/bin/env bats

load /code/scripts/common.sh

assert_equals() {
	local expected="$1"
	local actual="$2"
	if [[ "${expected}" != "${actual}" ]]; then
		echo "Expected: \"${expected}\", Got: \"${actual}\"" >&2
		return 1
	fi
}

setup() {
	DETECTED_PUBLIC_IP=""
}

@test "get_public_ip sets DETECTED_PUBLIC_IP on success" {
	curl() {
		echo "203.0.113.42"
	}
	export -f curl

	get_public_ip
	local result=$?

	assert_equals 0 "$result"
	assert_equals "203.0.113.42" "$DETECTED_PUBLIC_IP"
}

@test "get_public_ip handles IP with trailing whitespace" {
	curl() {
		echo "203.0.113.42
"
	}
	export -f curl

	get_public_ip

	assert_equals "203.0.113.42" "$DETECTED_PUBLIC_IP"
}

@test "get_public_ip uses custom AUTOSET_HOSTNAME_SERVICES" {
	curl() {
		echo "198.51.100.5"
	}
	export -f curl
	AUTOSET_HOSTNAME_SERVICES=("https://custom.service/ip")

	get_public_ip

	assert_equals "198.51.100.5" "$DETECTED_PUBLIC_IP"
}
