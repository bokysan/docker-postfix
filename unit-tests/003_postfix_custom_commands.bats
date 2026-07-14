#!/usr/bin/env bats

load /code/image_root/scripts/common.sh
load /code/image_root/scripts/functions.sh


@test "Make sure that postfix_custom_commands adds lines" {
    local POSTFIX_alias_database=lmdb:/etc/mail/aliases
    postfix_custom_commands
    cat /etc/postfix/main.cf | fgrep -qx "alias_database = lmdb:/etc/mail/aliases"
    postfix check
}

@test "Make sure that postfix_custom_commands removes lines" {
    local POSTFIX_readme_directory=
    postfix_custom_commands
    cat /etc/postfix/main.cf | egrep -q "^#readme_directory"
    postfix check
}
