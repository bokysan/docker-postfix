#!/bin/sh

noop() {
	while true; do
		# 2147483647 = max signed 32-bit integer
		# 2147483647 s ≅ 70 years
		sleep infinity || sleep 2147483647
	done
}

if [ ! -d /etc/opendkim/keys ]; then
	touch /tmp/no_open_dkim
	noop
elif [ -z "$(find /etc/opendkim/keys -type f ! -name .)" ]; then
	touch /tmp/no_open_dkim
	noop
else
	exec /usr/sbin/opendkim -D -f -x /etc/opendkim/opendkim.conf
fi


