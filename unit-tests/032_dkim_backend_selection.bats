#!/usr/bin/env bats

load /code/image_root/scripts/common.sh
load /code/image_root/scripts/functions.sh

@test "DKIM_BACKEND defaults to rspamd" {
	unset DKIM_BACKEND
	setup_dkim_backend
	[ "$DKIM_BACKEND" = "rspamd" ]
}

@test "DKIM_BACKEND accepts opendkim" {
	DKIM_BACKEND=opendkim
	setup_dkim_backend
	[ "$DKIM_BACKEND" = "opendkim" ]
}

@test "DKIM_BACKEND is case-insensitive" {
	DKIM_BACKEND=RSPAMD
	setup_dkim_backend
	[ "$DKIM_BACKEND" = "rspamd" ]
}

@test "DKIM_BACKEND rejects invalid values" {
	DKIM_BACKEND=nonsense
	run setup_dkim_backend
	[ "$status" -ne 0 ]
}

@test "rspamd backend wires postfix milter to 11332" {
	export DKIM_BACKEND=rspamd
	local ALLOWED_SENDER_DOMAINS=example.org
	rm -rf /var/lib/rspamd/dkim
	mkdir -p /var/lib/rspamd/dkim /etc/rspamd
	# Pretend a key is already present so DKIM gets enabled.
	: > /var/lib/rspamd/dkim/example.org.mail.key

	postfix_setup_dkim

	postconf smtpd_milters | grep -q "inet:localhost:11332"
	postconf non_smtpd_milters | grep -q "inet:localhost:11332"
	# The selector/path maps should have been generated.
	grep -qx "example.org mail" /etc/rspamd/dkim_selectors.map
	grep -q "example.org /var/lib/rspamd/dkim/example.org.mail.key" /etc/rspamd/dkim_paths.map
}
