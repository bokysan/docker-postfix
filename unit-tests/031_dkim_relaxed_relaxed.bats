#!/usr/bin/env bats

load /code/image_root/scripts/common.sh
load /code/image_root/scripts/functions.sh

mkdir -p /etc/opendkim
cp /code/image_root/etc/opendkim/opendkim.conf /etc/opendkim/opendkim.conf
chown -R opendkim:opendkim /etc/opendkim

@test "check if OpenDKIM can be set to relaxed/relaxed" {
    local DKIM_AUTOGENERATE=1
    local ALLOWED_SENDER_DOMAINS=example.org
    local OPENDKIM_Canonicalization="relaxed/relaxed"
    postfix_setup_dkim
    opendkim_custom_commands
    
    postfix check
    cat /etc/opendkim/opendkim.conf | grep -q "relaxed/relaxed"
}
