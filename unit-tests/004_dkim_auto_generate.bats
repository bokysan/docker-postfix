#!/usr/bin/env bats

load /code/image_root/scripts/common.sh
load /code/image_root/scripts/functions.sh

mkdir -p /etc/opendkim
cp /code/image_root/etc/opendkim/opendkim.conf /etc/opendkim/opendkim.conf
chown -R opendkim:opendkim /etc/opendkim

@test "check if private keys are readable by OpenDKIM" {
    # Sanity check
    su opendkim -s /bin/bash -c 'echo "Hello world"' > /dev/null

    local DKIM_AUTOGENERATE=1
    local ALLOWED_SENDER_DOMAINS=example.org
    local OPENDKIM_Mode=sv
    postfix_setup_dkim
    opendkim_custom_commands

    postfix check

    su opendkim -s /bin/bash -c 'cat /etc/opendkim/keys/example.org.private' > /dev/null
    su opendkim -s /bin/bash -c 'cat /etc/opendkim/keys/example.org.txt' > /dev/null
}
