#!/usr/bin/env bats

@test "verify hash email anonymizer default" {
	result="$(printf "prettyandsimple@example.com" | /code/image_root/scripts/email-anonymizer.sh 'hash?salt=hello%20world')"
	result=${result%$'\n'} # Remove trailing new line
	expected='{"msg": "<3052a860ddfde8b50e39843d8f1c9f591bec442823d97948b811d38779e2c757>"}'
	if [ "$result" != "$expected" ]; then
		echo "Expected '$expected', got: '$result' for email: $email" >&2
		error=1
	fi
	result="$(printf "PRETTYANDSIMPLE@EXAMPLE.COM" | /code/image_root/scripts/email-anonymizer.sh 'hash?salt=hello%20world')"
	result=${result%$'\n'} # Remove trailing new line
	if [ "$result" == "$expected" ]; then
		echo "Expected something different than '$expected', got: '$result'" >&2
		error=1
	fi
}

@test "verify hash email anonymizer no prefix and suffix" {
	result="$(printf "prettyandsimple@example.com" | /code/image_root/scripts/email-anonymizer.sh 'hash?salt=hello%20world&prefix=&suffix=')"
	result=${result%$'\n'} # Remove trailing new line
	expected='{"msg": "3052a860ddfde8b50e39843d8f1c9f591bec442823d97948b811d38779e2c757"}'
	if [ "$result" != "$expected" ]; then
		echo "Expected '$expected', got: '$result'" >&2
		error=1
	fi
}

@test "verify hash email anonymizer case-insensitive" {
	result="$(printf "PRETTYANDSIMPLE@EXAMPLE.COM" | /code/image_root/scripts/email-anonymizer.sh 'hash?salt=hello%20world&case_sensitive=false')"
	result=${result%$'\n'} # Remove trailing new line
	expected='{"msg": "<3052a860ddfde8b50e39843d8f1c9f591bec442823d97948b811d38779e2c757>"}'
	if [ "$result" != "$expected" ]; then
		echo "Expected '$expected', got: '$result'" >&2
		error=1
	fi
}

@test "verify hash email anonymizer split" {
	result="$(printf "PRETTYANDSIMPLE@EXAMPLE.COM" | /code/image_root/scripts/email-anonymizer.sh 'hash?salt=hello%20world&case_sensitive=false&split=1')"
	result=${result%$'\n'} # Remove trailing new line
	expected='{"msg": "<c58731d3c6216c2cd1b62408c904da3b0678dabeffb82b52ac371c969ebef9df@8bd7a35c91efae81e642e50c7432d16aaa708ebe8f91212a6e5f50843e1cbf97>"}'
	if [ "$result" != "$expected" ]; then
		echo "Expected '$expected', got: '$result'" >&2
		error=1
	fi
}

@test "verify hash email anonymizer short sha" {
	result="$(printf "PRETTYANDSIMPLE@EXAMPLE.COM" | /code/image_root/scripts/email-anonymizer.sh 'hash?salt=hello%20world&case_sensitive=false&split=1&prefix=~&suffix=~')"
	result=${result%$'\n'} # Remove trailing new line
	expected='{"msg": "~c58731d3@8bd7a35c~"}'
	if [ "$result" != "$expected" ]; then
		echo "Expected '$expected', got: '$result'" >&2
		error=1
	fi
}

@test "verify hash error for message id" {
	result="$(printf "20211207101128.0805BA272@31bfa77a2cab" | /code/image_root/scripts/email-anonymizer.sh 'hash?salt=hello%20world')"
	result=${result%$'\n'} # Remove trailing new line
	expected='{}'
	if [ "$result" != "$expected" ]; then
		echo "Expected '$expected', got: '$result' for email: $email" >&2
		error=1
	fi
}