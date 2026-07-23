#!/usr/bin/env bats

load /code/image_root/scripts/common.sh
load /code/image_root/scripts/functions.sh

setup() {
	export DKIM_BACKEND=rspamd
	rm -rf /etc/rspamd/local.d
	mkdir -p /etc/rspamd/local.d
}

teardown() {
	unset RSPAMD_dkim_signing__use_esld
}

@test "rspamd_custom_commands adds a setting" {
	export RSPAMD_dkim_signing__use_esld=false
	rspamd_custom_commands
	grep -qx "use_esld = false;" /etc/rspamd/local.d/dkim_signing.conf
}

@test "rspamd_custom_commands updates an existing setting" {
	echo "use_esld = true;" > /etc/rspamd/local.d/dkim_signing.conf
	export RSPAMD_dkim_signing__use_esld=false
	rspamd_custom_commands
	grep -qx "use_esld = false;" /etc/rspamd/local.d/dkim_signing.conf
	if grep -q "use_esld = true;" /etc/rspamd/local.d/dkim_signing.conf; then
		return 1
	fi
}

@test "rspamd_custom_commands removes a setting when the value is empty" {
	echo "use_esld = true;" > /etc/rspamd/local.d/dkim_signing.conf
	export RSPAMD_dkim_signing__use_esld=
	rspamd_custom_commands
	if grep -q "use_esld" /etc/rspamd/local.d/dkim_signing.conf; then
		return 1
	fi
}

@test "rspamd_custom_commands is a no-op for the opendkim backend" {
	export DKIM_BACKEND=opendkim
	export RSPAMD_dkim_signing__use_esld=false
	rspamd_custom_commands
	[ ! -f /etc/rspamd/local.d/dkim_signing.conf ]
}
