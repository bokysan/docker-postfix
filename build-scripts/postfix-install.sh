#!/bin/sh
set -e

if [ -f /etc/os-release ]; then
    . /etc/os-release
fi

do_alpine() {
    apk update
    apk add --upgrade cyrus-sasl cyrus-sasl-static cyrus-sasl-digestmd5 cyrus-sasl-crammd5 cyrus-sasl-login cyrus-sasl-ntlm libsasl
    apk add postfix
    apk add opendkim
    apk add --upgrade ca-certificates tzdata supervisor rsyslog musl musl-utils bash opendkim-utils libcurl jsoncpp lmdb logrotate netcat-openbsd
}

do_ubuntu() {
    RELEASE_SPECIFIC_PACKAGES="netcat"
    if [ "${ID}" = "debian" ]; then
        RELEASE_SPECIFIC_PACKAGES="netcat-openbsd"
    fi
    export DEBCONF_NOWARNINGS=yes
    export DEBIAN_FRONTEND=noninteractive
    echo "Europe/Berlin" > /etc/timezone
    apt-get update -y -q
    apt-get install -y libsasl2-modules sasl2-bin
    apt-get install -y postfix
    apt-get install -y opendkim
    apt-get install -y ca-certificates tzdata supervisor rsyslog bash opendkim-tools curl libcurl4 libjsoncpp25 sasl2-bin postfix-lmdb procps logrotate cron net-tools ${RELEASE_SPECIFIC_PACKAGES}
    apt-get clean
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*    
}

if [ -f /etc/alpine-release ]; then
    do_alpine
else
    do_ubuntu
fi

cp -r /etc/postfix /etc/postfix.template
