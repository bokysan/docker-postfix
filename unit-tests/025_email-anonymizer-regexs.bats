#!/usr/bin/env bats

mapfile EMAILS <<'EOF'
prettyandsimple@example.com
9453312: message-id=<1649523226559@test.example-org>
2F92E13: message-id=<8b38c47e1dd21675a07cf3bb674db074@example.com>
62D2E12: to=<demo@example.com>, relay=smtp.sendgrid.net[54.228.39.88]:587, delay=0.94, delays=0.1\/0.11\/0.61\/0.12, dsn=2.0.0, status=sent (250 Ok: queued as 5wukd4NoS6GaNrC3ggB83A)
77FCF13: message-id=<Issue1649425486405@postfix-mail.mail-system.svc.cluster.local> from=<test1@demo1.example.com> to=<test2@demo2.example.com>
77FCF13: message-id=Issue1649425486405@postfix-mail.mail-system.svc.cluster.local from=test1@demo1.example.com to=test2@demo2.example.com
9453312: message-id=<Issue1649523226559@postfix-mail.mail-system.svc.cluster.local>
9453312: message-id="Issue1649523226559@postfix-mail.mail-system.svc.cluster.local"
message-id=<Issue1649523226559@postfix-mail.mail-system.svc.cluster.local>
message-id=Issue1649523226559@postfix-mail.mail-system.svc.cluster.local
message-id=Issue1649523226559@postfix-mail.mail-system.svc.cluster.local
9453312: message-id='Issue1649523226559@postfix-mail.mail-system.svc.cluster.local'
9453312: message-id=Issue1649523226559@postfix-mail.mail-system.svc.cluster.local
EOF

mapfile EXPECTED <<'EOF'
{"msg": "*@*.com"}
{}
{}
{"msg": "62D2E12: to=<*@*.com>, relay=smtp.sendgrid.net[54.228.39.88]:587, delay=0.94, delays=0.1\\/0.11\\/0.61\\/0.12, dsn=2.0.0, status=sent (250 Ok: queued as 5wukd4NoS6GaNrC3ggB83A)"}
{"msg": "77FCF13: message-id=<Issue1649425486405@postfix-mail.mail-system.svc.cluster.local> from=<*@*.com> to=<*@*.com>"}
{"msg": "77FCF13: message-id=Issue1649425486405@postfix-mail.mail-system.svc.cluster.local *@*.com *@*.com"}
{}
{}
{}
{}
{}
{}
{}
EOF


@test "verify email anonymizer regex" {
	local email
	for index in "${!EMAILS[@]}"; do
		email="${EMAILS[$index]}"
		email=${email%$'\n'} # Remove trailing new line
		result="$(echo "$email" | /code/image_root/scripts/email-anonymizer.sh paranoid)"
		result=${result%$'\n'} # Remove trailing new line
		expected="${EXPECTED[$index]}"
		expected=${expected%$'\n'} # Remove trailing new line
		if [ "$result" != "$expected" ]; then
			echo "Expected '$expected', got: '$result'" >&2
			exit 1
		fi
	done
}

