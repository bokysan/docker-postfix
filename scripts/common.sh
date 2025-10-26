#!/usr/bin/env bash

declare reset green yellow orange orange_emphasis lightblue red gray emphasis underline

##################################################################################
# Check if one string is contained in another.
# Parameters:
#   $1 string to check
#   $2 the substring
#
# Exists:
#   0 (success) if $2 is in $1
#   1 (fail) if $2 is NOT in $1
#
# Example:
#   contains "foobar" "bar" -> 0 (true)
#   coinains "foobar" "e"   -> 1 (false)
#
##################################################################################
contains() {
	string="$1"
	substring="$2"
	if test "${string#*$substring}" != "$string"; then return 0; else return 1; fi
}

##################################################################################
# Check if we're running on a color term or not and setup color codes appropriately
##################################################################################
is_color_term() {
	if test -t 1 || [[ -n "$FORCE_COLOR" ]]; then
		# Quick and dirty test for color support
		if [ "$FORCE_COLOR" == "256" ] || contains "$TERM" "256" || contains "$COLORTERM" "256"  || contains "$COLORTERM" "color" || contains "$COLORTERM" "24bit"; then
			reset="$(printf '\033[0m')"
			green="$(printf '\033[38;5;46m')"
			yellow="$(printf '\033[38;5;178m')"
			orange="$(printf '\033[38;5;208m')"
			orange_emphasis="$(printf '\033[38;5;220m')"
			lightblue="$(printf '\033[38;5;147m')"
			red="$(printf '\033[91m')"
			gray="$(printf '\033[38;5;245m')"
			emphasis="$(printf '\033[38;5;111m')"
			underline="$(printf '\033[4m')"
		elif [ -n "$FORCE_COLOR" ] || contains "$TERM" "xterm"; then
			reset="$(printf '\033[0m')"
			green="$(printf '\033[32m')"
			yellow="$(printf '\033[33m')"
			orange="$(printf '\033[31m')"
			orange_emphasis="$(printf '\033[31m\033[1m')"
			lightblue="$(printf '\033[36;1m')"
			red="$(printf '\033[31;1m')"
			gray="$(printf '\033[30;1m')"
			emphasis="$(printf '\033[1m')"
			underline="$(printf '\033[4m')"
		fi
	fi
}
is_color_term


deprecated() {
	printf "${reset}‣ ${lightblue}DEPRECATED!${reset} "
	echo -e "$@${reset}"
}

debug() {
	printf "${reset}‣ ${gray}DEBUG${reset} "
	echo -e "$@${reset}"
}

info() {
	printf "${reset}‣ ${green}INFO ${reset} "
	echo -e "$@${reset}"
}

infon() {
	printf "${reset}‣ ${green}INFO ${reset} "
	echo -en "$@${reset}"
}

notice() {
	printf "${reset}‣ ${yellow}NOTE ${reset} "
	echo -e "$@${reset}"
}

noticen() {
	printf "${reset}‣ ${yellow}NOTE ${reset} "
	echo -en "$@${reset}"
}

warn() {
	printf "${reset}‣ ${orange}WARN ${reset} "
	echo -e "$@${reset}"
}

error() {
	printf "${reset}‣ ${red}ERROR${reset} " >&2
	echo -e "$@${reset}" >&2
}

fatal_no_exit() {
	printf "${reset}‣ ${red}FATAL${reset} " >&2
	echo -e "$@${reset}" >&2
}

fatal() {
	fatal_no_exit $@
	exit 1
}

# Return a DKIM selector from DKIM_SELECTOR environment variable.
# See README.md for details.
get_dkim_selector() {
	if [[ -z "${DKIM_SELECTOR}" ]]; then
		echo "mail"
		return
	fi

	local domain="$1"
	local old="$IFS"
	local no_domain_selector="mail"
	local IFS=","
	for part in ${DKIM_SELECTOR}; do
		if contains "$part" "="; then
			k="$(echo "$part" | cut -f1 -d=)"
			v="$(echo "$part" | cut -f2 -d=)"
			if [ "$k" == "$domain" ]; then
				echo "$v"
				IFS="${old}"
				return
			fi
		else
			no_domain_selector="$part"
		fi
	done
	IFS="${old}"

	echo "${no_domain_selector}"
}

do_postconf() {
	local is_clear
	local has_commented_key
	local has_key
	local key
	if [[ "$1" == "-#" ]]; then
		is_clear=1
		shift
		key="$1"
		shift
		if grep -q -E "^${key}\s*=" /etc/postfix/main.cf; then
			has_key="1"
		fi
		if grep -q -E "^#\s*${key}\s*=" /etc/postfix/main.cf; then
			has_commented_key="1"
		fi
		if [[ "${has_key}" == "1" ]] && [[ "${has_commented_key}" == "1" ]]; then
			# The key appears in the comment as well as outside the comment.
			# Delete the key which is outside of the comment
			sed -i -e "/^${key}\s*=/ { :a; N; /^\s/ba; N; d }" /etc/postfix/main.cf
		elif [[ "${has_key}" == "1" ]]; then
			# Comment out the key with postconf
			postconf -# "${key}" > /dev/null
		else
			# No key or only commented key, do nothing
			:
		fi
	else
		# Add the line normally
		shift
		postconf -e "$@"
	fi
}

############################
# Read a configuration from postfix configuration
############################
get_postconf() {
	local name="${1}"
	local result
	local error

	# This will throw a warning if the config option does not exist, e.g.
	# postconf: warning: foo_bar: unknown parameter

	# This is a bash magic to capture both out and error in the same line.
	# We're just basically calling "postconf <name>"
	. <({ error=$({ result="$(postconf "${name}")"; } 2>&1; declare -p result >&2); declare -p error; } 2>&1)

	if [[ -n "${error}" ]]; then
		error "Could not read variable ${emphasis}${name}${reset}: ${error}"
		return
	fi

	result="${result#*=}"
	result="${result#"${result%%[![:space:]]*}"}" # remove leading whitespace characters
	result="${result%"${result##*[![:space:]]}"}" # remove trailing whitespace characters
	printf '%s' "${result}"
}

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
#
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		error "Both $var and $fileVar are set (but are exclusive)"
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

# Return the directory where zone info is stored. Will return empy string if zoneinfo not found
zone_info_dir() {
	[[ -d /usr/share/zoneinfo ]] && printf "/usr/share/zoneinfo" && return
	[[ -d /var/db/timezone/zoneinfo ]] && printf "/var/db/timezone/zoneinfo" && return
	[[ -d /usr/lib/zoneinfo ]] && printf "/usr/lib/zoneinfo" && return
	return
}

###################################################################
# Remove leading and trailing whitespace from string
###################################################################
trim() {
	local var
	IFS='' read -d -r var
	#var="$(<&1)"
	# remove leading whitespace characters
	var="${var#"${var%%[![:space:]]*}"}"
	# remove trailing whitespace characters
	var="${var%"${var##*[![:space:]]}"}"
	printf '%s' "${var}"
}

###################################################################
# Potential fix for #180. Plugin names do not necessarily match
# filter names.
#
# This is an utility method which converts SASL plugin names into
# filter names. There's no reliable way to guess this, so the names
# have been hardcoded here.
#
# INPUT:
# The method expects as an input a list of plugin names, comma
# separated.
#
# OUTPUT:
# The list of plugin names, comma separated.
###################################################################
convert_plugin_names_to_filter_names() {
	local line first value lowercase
	while IFS=$',' read -ra line; do
		for value in "${line[@]}"; do
			value="$(printf '%s' "${value}" | trim)"
			if [[ -z "${value}" ]]; then
				continue;
			fi

			if [[ -z "${first}" ]]; then
				first="0"
			else
				printf '%s' ','
			fi

			lowercase="${value,,}"

			if [[ "${lowercase}" == "digestmd5" ]]; then
				printf '%s' 'DIGEST-MD5'
			elif [[ "${lowercase}" == "crammd5" ]]; then
				printf '%s' 'CRAM-MD5'
			else
				printf '%s' "${value}"
			fi
		done
	done
}

###################################################################
# Get the public IP of the server. Try different services to ensure
# that at least one works
###################################################################
get_public_ip() {
	local services=(https://ipinfo.io/ip https://ifconfig.me/ip https://icanhazip.com https://ipecho.net/ip https://ifconfig.co https://myexternalip.com/raw)
	local ip
	if [[ -n "${AUTOSET_HOSTNAME_SERVICES}" ]]; then
		services=("${AUTOSET_HOSTNAME_SERVICES}")
		notice "Using user defined ${emphasis}AUTOSET_HOSTNAME_SERVICES${reset}=${emphasis}${AUTOSET_HOSTNAME_SERVICES}${reset} for IP detection"
	else
		debug "Public IP detection will use ${emphasis}${services}${reset} to detect the IP."
	fi

	for service in "${services[@]}"; do
		if ip="$(curl --fail-early --retry-max-time 30 --retry 10 --connect-timeout 5 --max-time 10 -s)"; then
			# Some services, such as ifconfig.co will return a line feed at the end of the response.
			ip="$(printf "%s" "${ip}" | trim)"
			if [[ -n "${ip}" ]]; then
				info "Detected public IP address as ${emphasis}${services}${ip}${reset}."
				break
			fi
		fi
	done

	error "Unable to detect public IP. Please check your internet connection and firewall settings."
	return 1
}

export reset green yellow orange orange_emphasis lightblue red gray emphasis underline
