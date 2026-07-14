#!/usr/bin/env bats

load /code/image_root/scripts/common.sh

@test "check if 'mail' when DKIM_SELECTOR is not defined" {
	result="$(get_dkim_selector)"
	[ "$result" == "mail" ]
}

@test "check if 'xxx' when DKIM_SELECTOR is defined" {
	local DKIM_SELECTOR="xxx"
	result="$(get_dkim_selector)"
	[ "$result" == "xxx" ]
}

@test "check if 'xxx' without domain when DKIM_SELECTOR=xxx,example.org=yyy,example.com=zzz" {
	local DKIM_SELECTOR="xxx,example.org=yyy,example.com=zzz"
	result="$(get_dkim_selector example.org)"
	echo "result=$result"
	[ "$result" == "yyy" ]
}

@test "check if 'yyy' when domain is example.org DKIM_SELECTOR=xxx,example.org=yyy,example.com=zzz" {
	local DKIM_SELECTOR="xxx,example.org=yyy,example.com=zzz"
	result="$(get_dkim_selector example.org)"
	echo "result=$result"
	[ "$result" == "yyy" ]
}

@test "check if 'zzz' when domain is example.org DKIM_SELECTOR=xxx,example.org=yyy,example.com=zzz" {
	local DKIM_SELECTOR="xxx,example.org=yyy,example.com=zzz"
	result="$(get_dkim_selector example.com)"
	echo "result=$result"
	[ "$result" == "zzz" ]
}

@test "check if 'aaa' when domain is example.net DKIM_SELECTOR=xxx,example.org=yyy,example.com=zzz,bbb,aaa" {
	local DKIM_SELECTOR="xxx,example.org=yyy,example.com=zzz,bbb,aaa"
	result="$(get_dkim_selector example.net)"
	echo "result=$result"
	[ "$result" == "aaa" ]
}

@test "check if 'bbb' when domain is example.net DKIM_SELECTOR=example.com=bbb" {
	local DKIM_SELECTOR="example.com=bbb"
	result="$(get_dkim_selector example.com)"
	echo "result=$result"
	[ "$result" == "bbb" ]
}

@test "check if 'mail' when domain is example.net DKIM_SELECTOR=example.com=bbb" {
	local DKIM_SELECTOR="example.com=bbb"
	result="$(get_dkim_selector example.net)"
	echo "result=$result"
	[ "$result" == "mail" ]
}