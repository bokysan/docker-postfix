#!/usr/bin/env bats

load /code/image_root/scripts/common.sh
load /code/image_root/scripts/functions.sh

@test "check if SMTPD_SASL_USERS works with and without domain" {
	local db_file
	local SMTPD_SASL_USERS="hello:world,foo@example.com:bar"
	do_postconf -e 'mydomain=example.org'
	postfix_setup_smtpd_sasl_auth

	postfix check

	[[ -f /etc/postfix/sasl/smtpd.conf ]]
	[[ -f /etc/sasl2/smtpd.conf ]]
	[[ -f /etc/sasldb2 ]] || [[ -f /etc/sasl2/sasldb2 ]]

	sasldblistusers2 | grep -qE "^hello@example.org:"
	sasldblistusers2 | grep -qE "^foo@example.com:"

}

