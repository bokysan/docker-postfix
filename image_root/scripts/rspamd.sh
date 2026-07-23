#!/bin/sh

noop() {
	while true; do
		# 2147483647 = max signed 32-bit integer
		# 2147483647 s ≅ 70 years
		sleep infinity || sleep 2147483647
	done
}

# Debian names the account "_rspamd", Alpine names it "rspamd". Pick whichever exists.
rspamd_user() {
	if grep -q -E "^_rspamd:" /etc/passwd; then
		echo "_rspamd"
	else
		echo "rspamd"
	fi
}

rspamd_bin="$(command -v rspamd 2>/dev/null)"

if [ "${DKIM_BACKEND}" != "rspamd" ]; then
	# OpenDKIM (or no) backend selected -- stay out of the way.
	touch /tmp/no_rspamd
	noop
elif [ -z "${rspamd_bin}" ]; then
	# rspamd is not installed (not available on this architecture). Should not
	# happen -- setup_dkim_backend falls back to opendkim -- but stay safe.
	touch /tmp/no_rspamd
	noop
elif [ ! -d /var/lib/rspamd/dkim ]; then
	touch /tmp/no_rspamd
	noop
elif [ -z "$(find /var/lib/rspamd/dkim -type f ! -name .)" ]; then
	touch /tmp/no_rspamd
	noop
else
	user="$(rspamd_user)"
	exec "${rspamd_bin}" -f -u "${user}" -g "${user}"
fi
