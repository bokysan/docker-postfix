#!/bin/sh

# Wait for the configured DKIM milter (rspamd on 11332, or OpenDKIM on 8891) to
# start accepting connections before starting Postfix. Otherwise, during the few
# seconds the milter needs to come up, Postfix would fail open
# (milter_default_action=accept) and accept mail *unsigned*.
#
# If no inet: milter is configured (DKIM disabled, or a unix: socket milter),
# Postfix starts immediately.

wait_for_milter() {
	host="$1"
	port="$2"
	i=0
	echo "Waiting for the DKIM milter at ${host}:${port} to become available before starting Postfix..."
	while [ "$i" -lt 30 ]; do
		if nc -z "$host" "$port" 2>/dev/null; then
			echo "DKIM milter ${host}:${port} is up. Starting Postfix."
			return 0
		fi
		sleep 1
		i=$((i + 1))
	done
	echo "WARNING: DKIM milter ${host}:${port} did not come up within 30s. Starting Postfix anyway (mail may be accepted unsigned until the milter is ready)."
	return 0
}

milters="$(postconf -h smtpd_milters 2>/dev/null)"

case "$milters" in
	*inet:*)
		# Extract host:port from the first inet: milter spec, e.g. inet:localhost:11332
		spec="$(echo "$milters" | tr ', ' '\n' | grep '^inet:' | head -1)"
		hostport="${spec#inet:}"
		host="${hostport%:*}"
		port="${hostport##*:}"
		if [ -n "$host" ] && [ -n "$port" ]; then
			wait_for_milter "$host" "$port"
		fi
		;;
esac

exec /usr/sbin/postfix -c /etc/postfix start-fg
