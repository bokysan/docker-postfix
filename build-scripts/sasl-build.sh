#!/usr/bin/env bash
set -e

[ -f /etc/lsb-release ] && . /etc/lsb-release
[ -f /etc/os-release ] && . /etc/os-release

# Alpine os-release
# PRETTY_NAME="Alpine Linux v3.21"
# NAME="Alpine Linux"
# ID=alpine
# VERSION_ID=3.21.2
# HOME_URL="https://alpinelinux.org/"
# BUG_REPORT_URL="https://gitlab.alpinelinux.org/alpine/aports/-/issues"
# 
# Debian os-release
# PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
# NAME="Debian GNU/Linux"
# ID=debian
# VERSION_ID="12"
# VERSION="12 (bookworm)"
# VERSION_CODENAME=bookworm
# HOME_URL="https://www.debian.org/"
# SUPPORT_URL="https://www.debian.org/support"
# BUG_REPORT_URL="https://bugs.debian.org/"
#
# Ubuntu os-release
# PRETTY_NAME="Ubuntu 24.04.1 LTS"
# NAME="Ubuntu"
# ID=ubuntu
# ID_LIKE=debian
# VERSION_ID="24.04"
# VERSION="24.04.1 LTS (Noble Numbat)"
# VERSION_CODENAME=noble
# HOME_URL="https://www.ubuntu.com/"
# SUPPORT_URL="https://help.ubuntu.com/"
# BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
# PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
# UBUNTU_CODENAME=noble
# LOGO=ubuntu-logo

export DEBIAN_FRONTEND=noninteractive
export arch="$(uname -m)"
export skip_msal=""

if ([[ "${ID:-}" == "alpine" ]] \
        && ( [[ "${arch}" == "386" ]] || [[ "${arch}" == "i386" ]] ) ) \
    || [[ "${arch}" == "mips64el" ]]; then
	skip_msal="1"
	echo "Running on ${ID}/${arch}: Skipping msal install: ${skip_msal}"
else
	echo "Running on ${ID}/${arch}: Installing msal"
fi

# Build the sasl2 library with the sasl-xoauth2 plugin.
#
# The sasl-xoauth2 plugin is a SASL plugin that provides support for XOAUTH2 (OAuth 2.0) authentication.
#
# The build is done in /sasl-xoauth2/build.
#
# This script clones the sasl-xoauth2 repository, applies patches to:
# - remove the build of the documentation
# - fix the path to the python interpreter in the sasl-xoauth2-tool
# - fix the path to the library when building on Alpine
#
# After building and installing the sasl2 library with the sasl-xoauth2 plugin, the
# postfix-sasl-xoauth2-update-ca-certs script is installed into the /etc/ca-certificates/update.d directory.
# This script is run by the update-ca-certificates command to update the list of trusted certificates.
build_sasl2() {
	if [[ "${SASL_XOAUTH2_GIT_REF}" =~ [a-z0-9]{40} ]]; then
		# It's a specific commit that we're after
		git clone --depth 1 ${SASL_XOAUTH2_REPO_URL} /sasl-xoauth2
		cd /sasl-xoauth2
		git checkout ${SASL_XOAUTH2_GIT_REF}
	else
		# It's a branch
		git clone --depth 1 --branch ${SASL_XOAUTH2_GIT_REF} ${SASL_XOAUTH2_REPO_URL} /sasl-xoauth2
		cd /sasl-xoauth2
	fi
	mkdir build
	cd build
	# Documentation build (now) requires pandoc, which is not available on multiple
	# architectures. Since we're are building an image that we want it to be as slim as possible,
	# we're removing the build of documentation instead of complicating things with pandoc.
	patch -p1 -d .. < /build-scripts/sasl-xoauth2-01.patch

	# Ensure that the sasl-xoauth2-tool uses python from the virtual environment into which we
	# installed the msal library.
	patch -p1 -d .. < /build-scripts/sasl-xoauth2-03.patch

	if [ -f /etc/alpine-release ]; then
		patch -p1 -d .. < /build-scripts/sasl-xoauth2-02.patch
		cmake -DCMAKE_INSTALL_PREFIX=/ ..
	else
		cmake -DCMAKE_INSTALL_PREFIX=/usr ..
	fi
	make
	make install
	install ../scripts/postfix-sasl-xoauth2-update-ca-certs /etc/ca-certificates/update.d
	update-ca-certificates
}

# Installs rust. Debian bookwork comes with an old version of rust, so we can't use the one from the repository.
# Rust is needed, though for installation of msal library. On some architectures, we cannot use pre-compiled packages
# (because they don't exist in the PIP repositories) and "pip install" will fail without rust. Specifically, when
# compiling cryptographic libraries.
setup_rust() {
	if [[ -z "${skip_msal}" ]]; then
		curl --proto '=https' --tlsv1.3 https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal
		export PATH="$HOME/.cargo/bin:$PATH"
		. "$HOME/.cargo/env"
	fi
}

teardown_rust() {
	if command -v rustup 2>&1 > /dev/null; then
		rustup self uninstall -y
	fi
}

# Create a virtual environment and install the msal library for the
# sasl-xoauth2-tool.
setup_python_venv() {
	python3 -m venv /sasl
	. /sasl/bin/activate
	if [[ -z "${skip_msal}" ]]; then
		pip3 install msal
	fi
}

# Installs the base components into the docker image:
#
# 1. sasl2 using the sasl-xoauth2 plugin
# 2. a python virtual environment with the msal library
base_install() {
	build_sasl2
	setup_python_venv
}

# Determine the base installation method based on the OS.
# Alpine Linux has a different package management system than Debian-based systems.
if [ -f /etc/alpine-release ]; then
	# Install necessary libraries
	LIBS="git cmake clang make gcc g++ libc-dev pkgconfig curl-dev jsoncpp-dev cyrus-sasl-dev patch libffi-dev python3-dev rust cargo"
	apk add --upgrade curl
	apk add --upgrade --virtual .build-deps ${LIBS}

	# Run compilation and installation
	base_install

	# Cleanup. This is important to ensure that we don't keep unnecessary files laying around and thus increasing the size of the image.
	apk del .build-deps;
else
	# Install necessary libraries
	apt-get update -y -qq
	LIBS="git build-essential cmake pkg-config libcurl4-openssl-dev libssl-dev libjsoncpp-dev libsasl2-dev python3-dev python3-venv"
	apt-get install -y --no-install-recommends ${LIBS}

	# Run compilation and installation
	setup_rust
	base_install
	teardown_rust

	# Cleanup. This is important to ensure that we don't keep unnecessary files laying around and thus increasing the size of the image.
	apt-get remove --purge -y ${LIBS} python3-venv
	apt-get autoremove --yes
	apt-get clean autoclean
fi

