#!/usr/bin/env bats

load /code/scripts/common.sh
load /code/scripts/functions.sh

assert_equals() {
	local expected="$1"
	local actual="$2"
	if [[ "${expected}" != "${actual}" ]]; then
		echo "Expected: \"${expected}\", Got: \"${actual}\"" >&2
		return 1
	fi
}

setup() {
	POSTFIX_myhostname=""
	AUTOSET_HOSTNAME=""
	DETECTED_PUBLIC_IP=""

	do_postconf() {
		:
	}
	export -f do_postconf
}

@test "postfix_set_hostname respects explicit POSTFIX_myhostname" {
	POSTFIX_myhostname="mail.example.com"
	AUTOSET_HOSTNAME="1"

	postfix_set_hostname

	assert_equals "mail.example.com" "$POSTFIX_myhostname"
}

@test "postfix_set_hostname falls back to HOSTNAME when disabled" {
	POSTFIX_myhostname=""
	AUTOSET_HOSTNAME=""
	export HOSTNAME="test-container"

	postfix_set_hostname

	assert_equals "test-container" "$POSTFIX_myhostname"
}

@test "postfix_set_hostname auto-detects with reverse DNS when IP available" {
	POSTFIX_myhostname=""
	AUTOSET_HOSTNAME="1"
	DETECTED_PUBLIC_IP="203.0.113.42"

	# Mock get_public_ip to avoid curl calls
	get_public_ip() {
		return 0
	}
	export -f get_public_ip

	dig() {
		echo "mail.example.com."
	}
	export -f dig

	postfix_set_hostname

	assert_equals "mail.example.com" "$POSTFIX_myhostname"
}

@test "postfix_set_hostname removes trailing dot from dig" {
	POSTFIX_myhostname=""
	AUTOSET_HOSTNAME="1"
	DETECTED_PUBLIC_IP="203.0.113.42"

	get_public_ip() {
		return 0
	}
	export -f get_public_ip

	dig() {
		echo "example.com."
	}
	export -f dig

	postfix_set_hostname

	assert_equals "example.com" "$POSTFIX_myhostname"
}
