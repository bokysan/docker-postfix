#!/bin/sh

if [ -f /usr/sbin/cron ]; then # Ubuntu
	exec /usr/sbin/cron -f
else # Alpine / Busybox cron
	exec /usr/sbin/crond -f -S
fi