#!/usr/bin/env bats

mapfile EMAILS <<'EOF'
prettyandsimple@example.com
very.common@example.com
disposable.style.email.with+symbol@example.com
other.email-with-dash@example.com
x@example.com
"much.more unusual"@example.com
"very.unusual.@.unusual.com"@example.com
"very.(),:;<>[]\".VERY.\"very@\ \"very\".unusual"@strange.example.com
example-indeed@strange-example.com
admin@mailserver1
#!$%&'*+-/=?^_`{}|~@example.org
"()<>[]:,;@\\"!#$%&'-/=?^_`{}| ~.a"@example.org
" "@example.org
example@localhost
example@s.solutions
user@com
user@localserver
user@[127.0.0.1]
user@[IPv6:2001:db8::1]
Pelé@example.com
δοκιμή@παράδειγμα.δοκιμή
我買@屋企.香港
二ノ宮@黒川.日本
медведь@с-балалайкой.рф
संपर्क@डाटामेल.भारत
EOF

mapfile SMART <<'EOF'
*@*.com
*@*.com
*@*.com
*@*.com
*@*.com
*@*.com
*@*.com
*@*.com
*@*.com
*@*
*@*.org
*@*.org
*@*.org
*@*
*@*.solutions
*@*
*@*
*@[*]
*@[IPv6:*]
*@*.com
*@*.δοκιμή
*@*.香港
*@*.日本
*@*.рф
*@*.भारत
EOF

mapfile MESSAGE_IDS <<'EOF'
20211207101128.0805BA272@31bfa77a2cab
EOF

@test "verify paranoid email anonymizer" {
	local error
	local email
	for index in "${!EMAILS[@]}"; do
		email="${EMAILS[$index]}"
		email=${email%$'\n'} # Remove trailing new line
		result="$(echo "$email" | /code/scripts/email-anonymizer.sh paranoid)"
		result=${result%$'\n'} # Remove trailing new line
		expected="${SMART[$index]}"
		expected=${expected%$'\n'}  # Remove trailing new line
		expected="{\"msg\": \"${expected}\"}"
		if [ "$result" != "$expected" ]; then
			echo "Expected '$expected', got: '$result' for email: $email" >&2
			error=1
		fi
	done
	if [[ -n "$error" ]]; then
		exit 1
	fi
}

@test "verify paranoid error for message id" {
	local email
	for index in "${!MESSAGE_IDS[@]}"; do
		email="${MESSAGE_IDS[$index]}"
		email=${email%$'\n'} # Remove trailing new line
		result="$(echo "$email" | /code/scripts/email-anonymizer.sh paranoid)"
		result=${result%$'\n'} # Remove trailing new line
		expected='{}'
		if [ "$result" != "$expected" ]; then
			echo "Expected '$expected', got: '$result'" >&2
			exit 1
		fi
	done
}