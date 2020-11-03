#!/usr/bin/env bats

if [ -z "$FROM" ]; then
  FROM=$1
  shift
fi

if [ -z "$TO" ]; then
  TO=$1
  shift
fi

# Wait for postfix to startup
wait-for-service -q tcp://postfix_test_587:587

SMTP_DATA="-smtp postfix_test_587 -port 587"

load /common/common-xoauth2.sh

@test "Relay email with proper credentials" {
	local message_id="12345.test@example.com"
	local postfix_message_id=''
	local smtp_result=''
	local status=''

	mailsend \
		-sub "Test email 1" $SMTP_DATA \
		-from $FROM \
		-to $TO \
		header \
			-name "Message-ID" \
			-value "${message_id}" \
		body \
			-msg "Hello world!\nThis is a simple test message!"

	postfix_message_id=$(get_postfix_message_id '/logs/postfix.log' ${message_id})
	smtp_result=$(get_smtp_result '/logs/postfix.log' "${postfix_message_id}")
	status=$(get_param_value "${smtp_result}" 'status')

	[ -n "$status" ]
	echo "$status" | grep -q -E "^sent"
}
