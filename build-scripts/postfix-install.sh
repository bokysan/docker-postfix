#!/bin/sh
set -e


do_alpine() {
    apk update
    apk add --upgrade cyrus-sasl cyrus-sasl-static cyrus-sasl-digestmd5 cyrus-sasl-crammd5 cyrus-sasl-login cyrus-sasl-ntlm
    apk add postfix
    apk add opendkim
    apk add --upgrade ca-certificates tzdata supervisor rsyslog musl musl-utils bash opendkim-utils libcurl jsoncpp lmdb
}

do_ubuntu() {
    export DEBIAN_FRONTEND=noninteractive
    echo "Europe/Berlin" > /etc/timezone
    apt-get update -y -q
    apt-get install -y libsasl2-modules
    apt-get install -y postfix
    apt-get install -y opendkim
    apt-get install -y ca-certificates tzdata supervisor rsyslog bash opendkim-tools curl libcurl4 libjsoncpp1 sasl2-bin postfix-lmdb netcat
}

if [ -f /etc/alpine-release ]; then
    do_alpine
else
    do_ubuntu
fi

cp -r /etc/postfix /etc/postfix.template
