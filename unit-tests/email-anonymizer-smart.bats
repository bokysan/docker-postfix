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
p*e@*******.com
v*n@*******.com
d*l@*******.com
o*h@*******.com
x*x@*******.com
\"m*l\"@*******.com
\"v*m\"@*******.com
\"v*l\"@***************.com
e*d@***************.com
a*n@***********
#*~@*******.org
\"(*a\"@*******.org
\" * \"@*******.org
e*e@*********
e*e@*.solutions
u*r@***
u*r@***********
u*r@[*.*.*.*]
u*r@[IPv6:***********]
P*é@*******.com
δ*ή@**********.δοκιμή
我*買@**.香港
二*宮@**.日本
м*ь@************.рф
स*क@*******.भारत
20211207101128.0805BA272@31bfa77a2cab
EOF

mapfile MESSAGE_IDS <<'EOF'
20211207101128.0805BA272@31bfa77a2cab
EOF

@test "verify smart email anonymizer" {
	local error
	local email
	for index in "${!EMAILS[@]}"; do
		email="${EMAILS[$index]}"
		email=${email%$'\n'} # Remove trailing new line
		result="$(echo "$email" | /code/scripts/email-anonymizer.sh smart)"
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

@test "verify smart error for message id" {
	local email
	for index in "${!MESSAGE_IDS[@]}"; do
		email="${MESSAGE_IDS[$index]}"
		email=${email%$'\n'} # Remove trailing new line
		result="$(echo "$email" | /code/scripts/email-anonymizer.sh smart)"
		result=${result%$'\n'} # Remove trailing new line
		expected='{}'
		if [ "$result" != "$expected" ]; then
			echo "Expected '$expected', got: '$result'" >&2
			exit 1
		fi
	done
}