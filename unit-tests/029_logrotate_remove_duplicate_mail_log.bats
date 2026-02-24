#!/usr/bin/env bats

load /code/scripts/common.sh
load /code/scripts/functions.sh

declare default_logrotate_conf_path
declare rsyslog_logrotate_conf_path
declare backup_default
declare backup_rsyslog
declare default_existed
declare rsyslog_existed

setup() {
	default_logrotate_conf_path="/etc/logrotate.d/logrotate.conf"
	rsyslog_logrotate_conf_path="/etc/logrotate.d/rsyslog"
	backup_default="$(mktemp -t logrotate-default.XXXXXX)"
	backup_rsyslog="$(mktemp -t logrotate-rsyslog.XXXXXX)"
	default_existed=0
	rsyslog_existed=0

	mkdir -p /etc/logrotate.d

	if [[ -f "$default_logrotate_conf_path" ]]; then
		default_existed=1
		cp "$default_logrotate_conf_path" "$backup_default"
	fi

	if [[ -f "$rsyslog_logrotate_conf_path" ]]; then
		rsyslog_existed=1
		cp "$rsyslog_logrotate_conf_path" "$backup_rsyslog"
	fi
}

teardown() {
	if [[ "$default_existed" == "1" ]]; then
		cp "$backup_default" "$default_logrotate_conf_path"
	else
		rm -f "$default_logrotate_conf_path"
	fi

	if [[ "$rsyslog_existed" == "1" ]]; then
		cp "$backup_rsyslog" "$rsyslog_logrotate_conf_path"
	else
		rm -f "$rsyslog_logrotate_conf_path"
	fi

	rm -f "$backup_default" "$backup_rsyslog"
}

@test "removes /var/log/mail.log from writable default logrotate config" {
	cat <<EOF > "$default_logrotate_conf_path"
/var/log/mail.log
/var/log/other.log
EOF
	chmod 0644 "$default_logrotate_conf_path"
	rm -f "$rsyslog_logrotate_conf_path"

	logrotate_remove_duplicate_mail_log

	! grep -q '^/var/log/mail.log' "$default_logrotate_conf_path"
	grep -q '^/var/log/other.log' "$default_logrotate_conf_path"
}

@test "does not fail or modify read-only default logrotate config" {
	if ! command -v su >/dev/null 2>&1; then
		skip "su command not available"
	fi

	cat <<EOF > "$default_logrotate_conf_path"
/var/log/mail.log
/var/log/other.log
EOF
	chmod 0644 "$default_logrotate_conf_path"
	rm -f "$rsyslog_logrotate_conf_path"

	run su nobody -s /bin/bash -c '. /code/scripts/common.sh; . /code/scripts/functions.sh; logrotate_remove_duplicate_mail_log'
	[ "$status" -eq 0 ]
	grep -q '^/var/log/mail.log' "$default_logrotate_conf_path"
}

@test "does not fail or modify read-only rsyslog config when default is missing" {
	if ! command -v su >/dev/null 2>&1; then
		skip "su command not available"
	fi

	rm -f "$default_logrotate_conf_path"
	cat <<EOF > "$rsyslog_logrotate_conf_path"
/var/log/mail.log
/var/log/other.log
EOF
	chmod 0644 "$rsyslog_logrotate_conf_path"

	run su nobody -s /bin/bash -c '. /code/scripts/common.sh; . /code/scripts/functions.sh; logrotate_remove_duplicate_mail_log'
	[ "$status" -eq 0 ]
	grep -q '^/var/log/mail.log' "$rsyslog_logrotate_conf_path"
}
