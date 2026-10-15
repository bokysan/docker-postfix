#!/usr/bin/env bats

load /code/image_root/scripts/common.sh
load /code/image_root/scripts/functions.sh

setup() {
	POSTFIXD_DIR="${BATS_TEST_TMPDIR}/spool"
	POSTFIXD_ETC=""
}

@test "postfix_enable_chroot copies the CA bundle into the chroot" {
	[ -f /etc/ssl/certs/ca-certificates.crt ]

	postfix_enable_chroot

	cmp /etc/ssl/certs/ca-certificates.crt "${POSTFIXD_DIR}/etc/ssl/certs/ca-certificates.crt"
}

@test "postfix_enable_chroot restores a CA bundle removed from an existing chroot" {
	mkdir -p "${POSTFIXD_DIR}/etc/ssl"

	postfix_enable_chroot

	[ -f "${POSTFIXD_DIR}/etc/ssl/certs/ca-certificates.crt" ]
}

@test "postfix_enable_chroot replaces a full certificate directory with just the CA bundle" {
	# Debian's configure-instance.sh deletes etc/ssl/certs from the chroot when this file is present
	mkdir -p "${POSTFIXD_DIR}/etc/ssl/certs"
	touch "${POSTFIXD_DIR}/etc/ssl/certs/GlobalSign_Root_CA.pem"

	postfix_enable_chroot

	[ ! -e "${POSTFIXD_DIR}/etc/ssl/certs/GlobalSign_Root_CA.pem" ]
	[ -f "${POSTFIXD_DIR}/etc/ssl/certs/ca-certificates.crt" ]
}

@test "postfix_enable_chroot makes /etc/ssl/cert.pem resolve inside the chroot" {
	# Alpine's libcurl defaults to /etc/ssl/cert.pem; Debian doesn't ship it
	[ -e /etc/ssl/cert.pem ] || skip "/etc/ssl/cert.pem does not exist on this distribution"

	postfix_enable_chroot

	cmp /etc/ssl/certs/ca-certificates.crt "${POSTFIXD_DIR}/etc/ssl/cert.pem"
}
