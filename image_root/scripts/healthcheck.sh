#!/bin/sh
set -e
if [ -f /tmp/container_is_terminating ]; then
	exit 0
fi

check_postfix() {
	local proxy_protocol="$(postconf postscreen_upstream_proxy_protocol | cut -f2- -d= | tr -d '[:blank:]')"
	check_string="EHLO healthcheck\nquit\n"

	if [ -n "$proxy_protocol" ]; then
		check_string="PROXY TCP4 127.0.0.1 127.0.0.1 587 587\n${check_string}"
		#                   ^--- proxied internet protocol and family
		#                        ^--- source address
		#                                  ^--- destination address
		#                                            ^--- source port
		#                                                ^--- destination port
	fi

	printf "${check_string}" | \
	{ while read l ; do sleep 1; echo $l; done } | \
	nc -w 2 127.0.0.1 587 | \
	grep -qE "^220.*ESMTP Postfix"
}

check_dkim() {
	if [ -f /tmp/no_open_dkim ]; then
		return
	fi
	printf '\x18Clocalhost\x004\x00\x00127.0.0.1\x00' | nc -w 2 127.0.0.1 8891
}

echo "Postfix check..."
check_postfix
echo "DKIM check..."
check_dkim
echo "All OK!"
