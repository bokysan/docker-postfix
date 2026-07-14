#!/usr/bin/env bats

load /code/image_root/scripts/common.sh
load /code/image_root/scripts/functions.sh

setup() {
	mkdir -p /etc/opendkim/
	cat > /etc/opendkim/opendkim.conf <<-EOF
	AutoRestart             Yes
	AutoRestartRate         10/1h
	UMask                   002
	Syslog                  Yes
	SyslogSuccess           Yes
	LogWhy                  No

	Canonicalization        relaxed/simple
	RequireSafeKeys         no

	ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
	InternalHosts           refile:/etc/opendkim/TrustedHosts
	KeyTable                refile:/etc/opendkim/KeyTable
	SigningTable            refile:/etc/opendkim/SigningTable

	Mode                    sv
	PidFile                 /var/run/opendkim/opendkim.pid
	SignatureAlgorithm      rsa-sha256

	UserID                  opendkim:opendkim
	Socket                  inet:8891@localhost

	SignHeaders             From,Sender,To,CC,Subject,Message-Id,Date,MIME-Version,Content-Type,Reply-To
	OversignHeaders         From,Sender,To,CC,Subject,Message-Id,Date,MIME-Version,Content-Type,Reply-To
	EOF
}

teardown() {
	rm -f /etc/opendkim/opendkim.conf
}

@test "Make sure that opendkim_custom_commands changes lines" {
	local OPENDKIM_RequireSafeKeys=yes
	opendkim_custom_commands
	cat /etc/opendkim/opendkim.conf | fgrep -qx "RequireSafeKeys         yes"
}

@test "Make sure that opendkim_custom_commands adds lines" {
	local OPENDKIM_CaptureUnknownErrors=yes
	opendkim_custom_commands
	cat /etc/opendkim/opendkim.conf | fgrep -qx "CaptureUnknownErrors    yes"
}

@test "Make sure that opendkim_custom_commands removes lines" {
	local OPENDKIM_SignHeaders=
	opendkim_custom_commands
	if cat /etc/opendkim/opendkim.conf | egrep -q "^SignHeaders"; then
		return 1
	fi
}


