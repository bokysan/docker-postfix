#!/usr/bin/env bats

load /code/image_root/scripts/common.sh
load /code/image_root/scripts/functions.sh

setup() {
	export DKIM_BACKEND=rspamd
	rm -rf /var/lib/rspamd/dkim /etc/opendkim/keys
	mkdir -p /etc/opendkim/keys
	echo "-----BEGIN PRIVATE KEY-----" > /etc/opendkim/keys/example.org.private
	echo "DUMMY" >> /etc/opendkim/keys/example.org.private
	echo "mail._domainkey IN TXT ( \"v=DKIM1;...\" )" > /etc/opendkim/keys/example.org.txt
}

@test "import copies OpenDKIM keys into rspamd" {
	rspamd_import_opendkim
	[ -f /var/lib/rspamd/dkim/example.org.mail.key ]
	[ -f /var/lib/rspamd/dkim/example.org.mail.txt ]
}

@test "import leaves the original OpenDKIM keys untouched" {
	rspamd_import_opendkim
	[ -f /etc/opendkim/keys/example.org.private ]
	[ -f /etc/opendkim/keys/example.org.txt ]
}

@test "import does not overwrite existing rspamd keys" {
	mkdir -p /var/lib/rspamd/dkim
	echo "EXISTING" > /var/lib/rspamd/dkim/example.org.mail.key
	rspamd_import_opendkim
	grep -qx "EXISTING" /var/lib/rspamd/dkim/example.org.mail.key
}

@test "import honours a custom DKIM selector" {
	local DKIM_SELECTOR=postfix
	rspamd_import_opendkim
	[ -f /var/lib/rspamd/dkim/example.org.postfix.key ]
}

@test "import is a no-op when there are no OpenDKIM keys" {
	rm -rf /etc/opendkim/keys
	mkdir -p /etc/opendkim/keys
	rspamd_import_opendkim
	[ -z "$(find /var/lib/rspamd/dkim -type f 2>/dev/null)" ]
}
