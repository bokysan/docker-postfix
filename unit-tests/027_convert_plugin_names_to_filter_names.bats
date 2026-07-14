#!/usr/bin/env bats

load /code/image_root/scripts/common.sh

assert_equals() {
	local expected="$1"
	local actual="$2"
	if [[ "${expected}" != "${actual}" ]]; then
		echo "Expected: \"${expected}\". Got: \"${actual}\"." >&2
		exit 1
	fi
}

@test "check if trim works properly" {
	assert_equals "bar" "$(echo "bar" | trim)"
	assert_equals "foo bar" "$(echo "foo bar" | trim)"
	assert_equals "foo bar" "$(echo "     foo bar" | trim)"
	assert_equals "foo bar" "$(echo "foo bar       " | trim)"
	assert_equals "foo bar" "$(echo "          foo bar       " | trim)"
	assert_equals "foo bar" "$(printf '%s' "			foo bar" | trim)"
	assert_equals "foo bar" "$(printf '%s' $'\t\tfoo bar\r\n' | trim)"
	assert_equals "foo bar" "$(printf '%s' $'		   	  foo bar\r\n' | trim)"
}

@test "check if convert_plugin_names_to_filter_names works" {
	assert_equals "foo" "$(echo "foo" | convert_plugin_names_to_filter_names)"
	assert_equals "foo,bar" "$(echo "foo,bar" | convert_plugin_names_to_filter_names)"
	assert_equals "foo,bar,baz" "$(echo "foo,     bar,      baz," | convert_plugin_names_to_filter_names)"
	assert_equals "DIGEST-MD5" "$(echo "digestmd5" | convert_plugin_names_to_filter_names)"
	assert_equals "CRAM-MD5" "$(echo "crammd5" | convert_plugin_names_to_filter_names)"
	assert_equals "DIGEST-MD5,ntlm,CRAM-MD5,plain,login,anonymous" "$(echo "digestmd5,ntlm,crammd5,plain,login,anonymous" | convert_plugin_names_to_filter_names)"
	assert_equals "DIGEST-MD5,ntlm,CRAM-MD5,plain,login,anonymous" "$(echo "DIGESTMD5,ntlm,CRAMMD5,plain,login,anonymous" | convert_plugin_names_to_filter_names)"

}

