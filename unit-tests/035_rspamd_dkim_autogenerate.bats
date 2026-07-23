#!/usr/bin/env bats

load /code/image_root/scripts/common.sh
load /code/image_root/scripts/functions.sh

setup() {
	export DKIM_BACKEND=rspamd
	rm -rf /var/lib/rspamd/dkim
}

@test "autogenerate creates an rspamd key and DNS record file" {
	local ALLOWED_SENDER_DOMAINS=example.org
	local DKIM_AUTOGENERATE=1
	rspamd_dkim_autogenerate
	[ -f /var/lib/rspamd/dkim/example.org.mail.key ]
	[ -f /var/lib/rspamd/dkim/example.org.mail.txt ]
	# The DNS record file should contain a DKIM TXT record.
	grep -q "v=DKIM1" /var/lib/rspamd/dkim/example.org.mail.txt
}

@test "autogenerate does not overwrite an existing key" {
	mkdir -p /var/lib/rspamd/dkim
	echo "EXISTING" > /var/lib/rspamd/dkim/example.org.mail.key
	local ALLOWED_SENDER_DOMAINS=example.org
	rspamd_dkim_autogenerate
	grep -qx "EXISTING" /var/lib/rspamd/dkim/example.org.mail.key
}

@test "autogenerate honours a custom selector" {
	local ALLOWED_SENDER_DOMAINS=example.org
	local DKIM_SELECTOR=postfix
	rspamd_dkim_autogenerate
	[ -f /var/lib/rspamd/dkim/example.org.postfix.key ]
}

@test "autogenerate warns and does nothing without ALLOWED_SENDER_DOMAINS" {
	rspamd_dkim_autogenerate
	[ -z "$(find /var/lib/rspamd/dkim -type f 2>/dev/null)" ]
}
