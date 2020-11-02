#!/usr/bin/env bats

load /code/scripts/common.sh
load /code/scripts/common-run.sh

@test "check sentive variables are unset" {
	local RELAYHOST_PASSWORD="password"
	local XOAUTH2_CLIENT_ID="client_id"
	local XOAUTH2_SECRET="secret"
	local XOAUTH2_INITIAL_ACCESS_TOKEN="access_token"
	local XOAUTH2_INITIAL_REFRESH_TOKEN="refres_token"

	unset_sensible_variables

	[ -z "$RELAYHOST_PASSWORD" ]
	[ -z "$XOAUTH2_CLIENT_ID" ]
	[ -z "$XOAUTH2_SECRET" ]
	[ -z "$XOAUTH2_INITIAL_ACCESS_TOKEN" ]
	[ -z "$XOAUTH2_INITIAL_REFRESH_TOKEN" ]
}

@test "reading sensitive values from environment or from file" {
	local RELAYHOST_PASSWORD="password"

	local tmp_file=$(mktemp)
	echo "password" > $tmp_file
	local XOAUTH2_CLIENT_ID_FILE="$tmp_file"

	file_env 'RELAYHOST_PASSWORD'
	file_env 'XOAUTH2_CLIENT_ID'

	[ -n "$RELAYHOST_PASSWORD" ]
	[ -n "$XOAUTH2_CLIENT_ID" ]
}

@test "pre-configure xoauth2 in postfix only if relayhost is configured" {
	local RELAYHOST="[smtp.example.org]:597"
	local RELAYHOST_USERNAME="your.acount@example.org"
	local XOAUTH2_CLIENT_ID="client_id"
	local XOAUTH2_SECRET="secret"
	local XOAUTH2_SYSLOG_ON_FAILURE="no"
	local XOAUTH2_FULL_TRACE="yes"
	local XOAUTH2_INITIAL_ACCESS_TOKEN="access_token"
	local XOAUTH2_INITIAL_REFRESH_TOKEN="refresh_token"

	postfix_setup_xoauth2_pre_setup

	[ -f "/etc/sasl-xoauth2.conf" ]
	result=$(cat /etc/sasl-xoauth2.conf | grep -e 'client_id' | sed -r 's/\s*"[^"]+"\s*:\s*"([^,]*)"\s*,?/\1/')
	[ "$result" == "$XOAUTH2_CLIENT_ID" ]
	result=$(cat /etc/sasl-xoauth2.conf | grep -e 'client_secret' | sed -r 's/\s*"[^"]+"\s*:\s*"([^,]*)"\s*,?/\1/')
	[ "$result" == "$XOAUTH2_SECRET" ]
	result=$(cat /etc/sasl-xoauth2.conf | grep -e 'log_to_syslog_on_failure' | sed -r 's/\s*"[^"]+"\s*:\s*"([^,]*)"\s*,?/\1/')
	[ "$result" == "$XOAUTH2_SYSLOG_ON_FAILURE" ]
	result=$(cat /etc/sasl-xoauth2.conf | grep -e 'log_full_trace_on_failure' | sed -r 's/\s*"[^"]+"\s*:\s*"([^,]*)"\s*,?/\1/')
	[ "$result" == "$XOAUTH2_FULL_TRACE" ]
	[ "$RELAYHOST_PASSWORD" == "/var/spool/postfix/xoauth2-tokens/${RELAYHOST_USERNAME}" ]
	result=$(cat "${RELAYHOST_PASSWORD}" | grep -e 'access_token' | sed -r 's/\s*"[^"]+"\s*:\s*"([^,]*)"\s*,?/\1/')
	[ "$result" == "$XOAUTH2_INITIAL_ACCESS_TOKEN" ]
	result=$(cat "${RELAYHOST_PASSWORD}" | grep -e 'refresh_token' | sed -r 's/\s*"[^"]+"\s*:\s*"([^,]*)"\s*,?/\1/')
	[ "$result" == "$XOAUTH2_INITIAL_REFRESH_TOKEN" ]
}

@test "pre-configure error trying to configure xoauth2 in postfix if relayhost is not configured" {
	local XOAUTH2_CLIENT_ID="client_id"
	local XOAUTH2_SECRET="secret"

	local RELAYHOST="[smtp.example.org]:597"

	run postfix_setup_xoauth2_pre_setup

	[ "$status" -eq 1 ]
	[ "$output" == "‣ ERROR You need to specify RELAYHOST and RELAYHOST_USERNAME otherwise Postfix will not run!" ]

	unset RELAYHOST
	local RELAYHOST_USERNAME="your.acount@example.org"

	run postfix_setup_xoauth2_pre_setup

	[ "$status" -eq 1 ]
	[ "$output" == "‣ ERROR You need to specify RELAYHOST and RELAYHOST_USERNAME otherwise Postfix will not run!" ]
}

@test "post-configure xoauth2 not needed" {
	local XOAUTH2_CLIENT_ID="client_id"

	postfix_setup_xoauth2_post_setup

	postfix check

	result=$(cat /etc/postfix/main.cf | grep -e 'smtp_sasl_mechanism_filter' | sed -r 's/\s*[^\s]+\s*=\s*([^\s]*)/\1/')
	[ "$result" != "xoauth2" ]
}

@test "post-configure xoauth2 required" {
	local XOAUTH2_CLIENT_ID="client_id"
	local XOAUTH2_SECRET="secret"

	postfix_setup_xoauth2_post_setup

	postfix check

	cat /etc/postfix/main.cf | grep -q -E '^\s*smtp_sasl_security_options\s*=\s*$'
	local status=$?
	[ "$status" -eq 0 ]

	cat /etc/postfix/main.cf | grep -q -E '^\s*smtp_sasl_mechanism_filter\s*=\s*xoauth2$'
	local status=$?
	[ "$status" -eq 0 ]

	cat /etc/postfix/main.cf | grep -q -E '^\s*smtp_tls_session_cache_database\s*=\s*btree:\$\{data_directory\}/smtp_scache$'
	local status=$?
	[ "$status" -eq 0 ]
}
