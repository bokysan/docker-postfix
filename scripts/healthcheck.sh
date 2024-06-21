#!/bin/sh
#set -e
if [ -f /tmp/container_is_terminating ]; then
    exit 0
fi

check_postfix() {
    port=$(grep -v '^#' /etc/postfix/master.cf | grep 'submission inet')
    if [ -n "$port" ]; then
        port=587
        echo "Submission port is: $port"
    else
        port=$(grep -E '^[^#].*smtpd$' /etc/postfix/master.cf | awk '{print $1}')
        echo "Submission port is: $port"
    fi
    printf "EHLO healthcheck\nquit\n" | \
    { while read l ; do sleep 1; echo $l; done } | \
    nc -w 2 127.0.0.1 $port | \
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
