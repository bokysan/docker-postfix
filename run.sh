#!/bin/sh

reset=""
yellow=""
yellow_bold=""
red=""
orange=""

# Returns 0 if the specified string contains the specified substring, otherwise returns 1.
# This exercise it required because we are using the sh-compatible interpretation instead
# of bash.
contains() {
    string="$1"
    substring="$2"
    if test "${string#*$substring}" != "$string"
    then
        return 0    # $substring is in $string
    else
        return 1    # $substring is not in $string
    fi
}

if test -t 1; then
	# Quick and dirty test for color support
	if contains "$TERM" "256" || contains "$COLORTERM" "256"  || contains "$COLORTERM" "color" || contains "$COLORTERM" "24bit"; then
		reset="\033[0m"
		green="\033[38;5;46m"
		yellow="\033[38;5;178m"
		red="\033[91m"
		orange="\033[38;5;208m"

		emphasis="\033[38;5;226m"
	elif contains "$TERM" "xterm"; then
		reset="\033[0m"
		green="\033[32m"
		yellow="\033[33m"
		red="\033[31;1m"
		orange="\033[31m"

		emphasis="\033[33;1m"
	fi
fi

info="${green}INFO:${reset}"
notice="${yellow}NOTE:${reset}"
warn="${orange}WARN:${reset}"

echo -e "******************************"
echo -e "**** POSTFIX STARTING UP *****"
echo -e "******************************"

# Check if we need to configure the container timezone
if [ ! -z "$TZ" ]; then
	TZ_FILE="/usr/share/zoneinfo/$TZ"
	if [ -f "$TZ_FILE" ]; then
		echo  -e "‣ $notice Setting container timezone to: ${emphasis}$TZ${reset}"
		ln -snf "$TZ_FILE" /etc/localtime
		echo "$TZ" > /etc/timezone
	else
		echo  -e "‣ $warn Cannot set timezone to: ${emphasis}$TZ${reset} -- this timezone does not exist."
	fi
else
	echo  -e "‣ $info Not setting any timezone for the container"
fi

# Make and reown postfix folders
mkdir -p /var/spool/postfix/ && mkdir -p /var/spool/postfix/pid
chown root: /var/spool/postfix/
chown root: /var/spool/postfix/pid

# Disable SMTPUTF8, because libraries (ICU) are missing in alpine
postconf -e smtputf8_enable=no

# Update aliases database. It's not used, but postfix complains if the .db file is missing
postalias /etc/postfix/aliases

# Disable local mail delivery
postconf -e mydestination=

# Don't relay for any domains
postconf -e relay_domains=

# Increase the allowed header size, the default (102400) is quite smallish
postconf -e "header_size_limit=4096000"

if [ ! -z "$MESSAGE_SIZE_LIMIT" ]; then
	echo  -e "‣ $notice Restricting message_size_limit to: ${emphasis}$MESSAGE_SIZE_LIMIT bytes${reset}"
	postconf -e "message_size_limit=$MESSAGE_SIZE_LIMIT"
else
	# As this is a server-based service, allow any message size -- we hope the 
	# sender knows what he is doing.
	echo  -e "‣ $info Using ${emphasis}unlimited${reset} message size."
	postconf -e "message_size_limit=0"
fi

# Reject invalid HELOs
postconf -e smtpd_delay_reject=yes
postconf -e smtpd_helo_required=yes
postconf -e "smtpd_helo_restrictions=permit_mynetworks,reject_invalid_helo_hostname,permit"
postconf -e "smtpd_sender_restrictions=permit_mynetworks"

# Set up host name
if [ ! -z "$HOSTNAME" ]; then
	echo  -e "‣ $notice Setting myhostname: ${emphasis}$HOSTNAME${reset}"
	postconf -e myhostname="$HOSTNAME"
else
	postconf -# myhostname
fi

if [ -z "$RELAYHOST_TLS_LEVEL" ]; then
	echo  -e "‣ $info Setting smtp_tls_security_level: ${emphasis}may${reset}"
	postconf -e "smtp_tls_security_level=may"
else
	echo  -e "‣ $notice Setting smtp_tls_security_level: ${emphasis}$RELAYHOST_TLS_LEVEL${reset}"
	postconf -e "smtp_tls_security_level=$RELAYHOST_TLS_LEVEL"
fi

# Set up a relay host, if needed
if [ ! -z "$RELAYHOST" ]; then
	echo -en "‣ $notice Forwarding all emails to ${emphasis}$RELAYHOST${reset}"
	postconf -e "relayhost=$RELAYHOST"
	# Alternately, this could be a folder, like this:
	# smtp_tls_CApath
	postconf -e "smtp_tls_CAfile=/etc/ssl/certs/ca-certificates.crt"

	if [ -n "$RELAYHOST_USERNAME" ] && [ -n "$RELAYHOST_PASSWORD" ]; then
		echo -e " using username ${emphasis}$RELAYHOST_USERNAME${reset} and password ${emphasis}(redacted)${reset}."
		echo "$RELAYHOST $RELAYHOST_USERNAME:$RELAYHOST_PASSWORD" >> /etc/postfix/sasl_passwd
		postmap hash:/etc/postfix/sasl_passwd
		postconf -e "smtp_sasl_auth_enable=yes"
		postconf -e "smtp_sasl_password_maps=hash:/etc/postfix/sasl_passwd"
		postconf -e "smtp_sasl_security_options=noanonymous"
		postconf -e "smtp_sasl_tls_security_options=noanonymous"
	else
		echo -e " without any authentication. ${emphasis}Make sure your server is configured to accept emails coming from this IP.${reset}"
	fi
else
	echo -e "‣ $notice Will try to deliver emails directly to the final server. ${emphasis}Make sure your DNS is setup properly!${reset}"
	postconf -# relayhost
	postconf -# smtp_sasl_auth_enable
	postconf -# smtp_sasl_password_maps
	postconf -# smtp_sasl_security_options
fi

if [ ! -z "$MYNETWORKS" ]; then
	echo  -e "‣ $notice Using custom allowed networks: ${emphasis}$MYNETWORKS${reset}"
else
	echo  -e "‣ $info Using default private network list for trusted networks."
	MYNETWORKS="127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
fi

postconf -e "mynetworks=$MYNETWORKS"

if [ ! -z "$INBOUND_DEBUGGING" ]; then
	echo  -e "‣ $notice Enabling additional debbuging for: ${emphasis}$MYNETWORKS${reset}"
	postconf -e "debug_peer_list=$MYNETWORKS"

	sed -i -E 's/^[ \t]*#?[ \t]*LogWhy[ \t]*.+$/LogWhy                  yes/' /etc/opendkim/opendkim.conf
	if ! egrep -q '^LogWhy' /etc/opendkim/opendkim.conf; then
		echo >> /etc/opendkim/opendkim.conf
		echo "LogWhy                  yes" >> /etc/opendkim/opendkim.conf
	fi
else
	sed -i -E 's/^[ \t]*#?[ \t]*LogWhy[ \t]*.+$/LogWhy                  no/' /etc/opendkim/opendkim.conf
	if ! egrep -q '^LogWhy' /etc/opendkim/opendkim.conf; then
		echo >> /etc/opendkim/opendkim.conf
		echo "LogWhy                  no" >> /etc/opendkim/opendkim.conf
	fi
fi

if [ ! -z "$ALLOWED_SENDER_DOMAINS" ]; then
	echo -en "‣ $info Setting up allowed SENDER domains:"
	allowed_senders=/etc/postfix/allowed_senders
	rm -f $allowed_senders $allowed_senders.db > /dev/null
	touch $allowed_senders
	for i in $ALLOWED_SENDER_DOMAINS; do
		echo -ne " ${emphasis}$i${reset}"
		echo -e "$i\tOK" >> $allowed_senders
	done
	echo
	postmap $allowed_senders

	postconf -e "smtpd_restriction_classes=allowed_domains_only"
	postconf -e "allowed_domains_only=permit_mynetworks, reject_non_fqdn_sender reject"
#   Update: loosen up on RCPT checks. This will mean we might get some emails which are not valid, but the service connecting
#           will be able to send out emails much faster, as there will be no lookup and lockup if the target server is not responing or available.
#	postconf -e "smtpd_recipient_restrictions=reject_non_fqdn_recipient, reject_unknown_recipient_domain, reject_unverified_recipient, check_sender_access hash:$allowed_senders, reject"
	postconf -e "smtpd_recipient_restrictions=reject_non_fqdn_recipient, reject_unknown_recipient_domain, check_sender_access hash:$allowed_senders, reject"

	# Since we are behind closed doors, let's just permit all relays.
	postconf -e "smtpd_relay_restrictions=permit"
else
	echo -e "ERROR: You need to specify ALLOWED_SENDER_DOMAINS otherwise Postfix will not run!"
	exit 1
fi

if [ ! -z "$MASQUERADED_DOMAINS" ]; then
	echo -e "‣ $notice Setting up address masquerading: ${emphasis}$MASQUERADED_DOMAINS${reset}"
	postconf -e "masquerade_domains = $MASQUERADED_DOMAINS"
	postconf -e "local_header_rewrite_clients = static:all"
fi

if [ ! -z "$HEADER_CHECKS" ]; then
	echo -e "‣ $notice Setting up header_checks"
	postconf -e "smtp_header_checks=regexp:/etc/header_checks"
fi

DKIM_ENABLED=
if [ -d /etc/opendkim/keys ] && [ ! -z "$(find /etc/opendkim/keys -type f ! -name .)" ]; then
	DKIM_ENABLED=", ${emphasis}opendkim${reset}"
	echo  -e "‣ $notice Configuring OpenDKIM."
	mkdir -p /var/run/opendkim
	chown -R opendkim:opendkim /var/run/opendkim
	dkim_socket=$(cat /etc/opendkim/opendkim.conf | egrep ^Socket | awk '{ print $2 }')
	if [ $(echo "$dkim_socket" | cut -d: -f1) == "inet" ]; then
		dkim_socket=$(echo "$dkim_socket" | cut -d: -f2)
		dkim_socket="inet:$(echo "$dkim_socket" | cut -d@ -f2):$(echo "$dkim_socket" | cut -d@ -f1)"
	fi
	echo -e "        ...using socket $dkim_socket"

	postconf -e "milter_protocol=6"
	postconf -e "milter_default_action=accept"
	postconf -e "smtpd_milters=$dkim_socket"
	postconf -e "non_smtpd_milters=$dkim_socket"

	echo > /etc/opendkim/TrustedHosts
	echo > /etc/opendkim/KeyTable
	echo > /etc/opendkim/SigningTable

	# Since it's an internal service anyways, it's safe
	# to assume that *all* hosts are trusted.
	echo "0.0.0.0/0" > /etc/opendkim/TrustedHosts

	if [ ! -z "$ALLOWED_SENDER_DOMAINS" ]; then
		for i in $ALLOWED_SENDER_DOMAINS; do
			private_key=/etc/opendkim/keys/$i.private
			if [ -f $private_key ]; then
				echo -e "        ...for domain ${emphasis}$i${reset}"
				echo "mail._domainkey.$i $i:mail:$private_key" >> /etc/opendkim/KeyTable
				echo "*@$i mail._domainkey.$i" >> /etc/opendkim/SigningTable
			else
				echo "  ...$warn skipping for domain ${emphasis}$i${reset}. File $private_key not found!"
			fi
		done
	fi
else
	echo  -e "‣ $info No DKIM keys found, will not use DKIM."
	postconf -# smtpd_milters
	postconf -# non_smtpd_milters
fi

# Use 587 (submission)
sed -i -r -e 's/^#submission/submission/' /etc/postfix/master.cf

if [ -d /docker-init.db/ ]; then
	echo -e "‣ $notice Executing any found custom scripts..."
	for f in /docker-init.db/*; do
		case "$f" in
			*.sh)     chmod +x "$f"; echo -e "\trunning ${emphasis}$f${reset}"; . "$f" ;;
			*)        echo "$0: ignoring $f" ;;
		esac
	done
fi

echo -e "‣ $notice Starting: ${emphasis}rsyslog${reset}, ${emphasis}postfix${reset}$DKIM_ENABLED"
exec supervisord -c /etc/supervisord.conf

