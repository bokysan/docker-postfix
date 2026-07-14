#!/usr/bin/env bats

load /code/image_root/scripts/common.sh
load /code/image_root/scripts/functions.sh


postconf daemon_directory=/usr/libexec/postfix

if [[ ! -f /etc/postfix/main.test-multi-comment ]]; then
	cp /etc/postfix/main.cf /etc/postfix/main.test-multi-comment
fi

@test "make sure #myhostname appears four times in main.cf (default)" {
	result=$(grep -E "^#myhostname" /etc/postfix/main.cf | wc -l)
	[[ "$result" -gt 1 ]]
}

@test "make sure commenting out #myhostname does not incrase count" {
	COMMENT_COUNT=$(grep -E "^#myhostname" /etc/postfix/main.test-multi-comment | wc -l)
	do_postconf -# myhostname
	postfix check
	result=$(grep -E "^#myhostname" /etc/postfix/main.cf | wc -l)
	[ "$result" == "$COMMENT_COUNT" ]
}

@test "make sure adding myhostname does not incrase count" {
	COMMENT_COUNT=$(grep -E "^#myhostname" /etc/postfix/main.test-multi-comment | wc -l)
	do_postconf -e myhostname=localhost
	postfix check
	result=$(grep -E "^#myhostname" /etc/postfix/main.cf | wc -l)
	[ "$result" == "$COMMENT_COUNT" ]
}

@test "make sure adding myhostname is added only once" {
	do_postconf -e myhostname=localhost
	postfix check
	result=$(grep -E "^myhostname" /etc/postfix/main.cf | wc -l)
	[ "$result" == "1" ]
}

@test "make sure deleting myhostname does not incrase count" {
	COMMENT_COUNT=$(grep -E "^#myhostname" /etc/postfix/main.test-multi-comment | wc -l)
	do_postconf -# myhostname
	postfix check
	result=$(grep -E "^#myhostname" /etc/postfix/main.cf | wc -l)
	[ "$result" == "$COMMENT_COUNT" ]
}

@test "test removing relayhost" {
	do_postconf -# relayhost
	grep -q -E "^#relayhost" /etc/postfix/main.cf
	! grep -q -E "^relayhost" /etc/postfix/main.cf
	postfix check
}

@test "spaces in parameters" {
	do_postconf -e "smtpd_recipient_restrictions=reject_non_fqdn_recipient, reject_unknown_recipient_domain, check_sender_access lmdb:example.org, reject"
	postfix check
}

@test "no sasl password duplications" {
	local RELAYHOST="demo"
	local RELAYHOST_USERNAME="foo"
	local RELAYHOST_PASSWORD="bar"

	postfix_setup_relayhost
	postfix_setup_relayhost

	postfix check

	result=$(grep -E "^demo" /etc/postfix/sasl_passwd | wc -l)
	[ "$result" == "1" ]
}