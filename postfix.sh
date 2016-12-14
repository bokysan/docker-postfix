#!/bin/bash

# Disable SMTPUTF8, because libraries (ICU) are missing in alpine
postconf -e smtputf8_enable=no

# Update aliases database. It's not used, but postfix complains if the .db file is missing
postalias /etc/postfix/aliases

# Disable local mail delivery
postconf -e mydestination=
# Don't relay for any domains
postconf -e relay_domains=

# Reject invalid HELOs
postconf -e smtpd_delay_reject=yes
postconf -e smtpd_helo_required=yes
postconf -e "smtpd_helo_restrictions=permit_mynetworks,reject_invalid_helo_hostname,permit"

# Set up host name
if [[ ! -z "$HOSTNAME" ]]; then
	postconf -e myhostname=$HOSTNAME
else
	postconf -# myhostname
fi

# Set up a relay host, if needed
if [[ ! -z "$RELAYHOST" ]]; then
	postconf -e relayhost=$RELAYHOST
else
	postconf -# relayhost
fi

# Set up my networks to list only networks in the local loopback range
#network_table=/etc/postfix/network_table
#touch $network_table
#echo "127.0.0.0/8    any_value" >  $network_table
#echo "10.0.0.0/8     any_value" >> $network_table
#echo "172.16.0.0/12  any_value" >> $network_table
#echo "192.168.0.0/16 any_value" >> $network_table
## Ignore IPv6 for now
##echo "fd00::/8" >> $network_table
#postmap $network_table
#postconf -e mynetworks=hash:$network_table

if [[ ! -z "$MYNETWORKS" ]]; then
        postconf -e relayhost=$MYNETWORKS
else
        postconf -e "mynetworks=127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
fi

# Split with space
if [[ ! -z "$ALLOWED_SENDER_DOMAINS" ]]; then
	echo "Setting up allowed SENDER domains:"
	allowed_senders=/etc/postfix/allowed_senders
	rm -f $allowed_senders $allowed_senders.db > /dev/null
	touch $allowed_senders
	for i in "$ALLOWED_SENDER_DOMAINS"; do
		echo -e "\t$i"
		echo -e "$i\tOK" >> $allowed_senders
	done
	postmap $allowed_senders

	postconf -e "smtpd_restriction_classes=allowed_domains_only"
	postconf -e "allowed_domains_only=permit_mynetworks, reject_non_fqdn_sender reject"
	postconf -e "smtpd_recipient_restrictions=reject_non_fqdn_recipient, reject_unknown_recipient_domain, reject_unverified_recipient, check_sender_access hash:$allowed_senders, reject"
else
	postconf -# "smtpd_restriction_classes"
	postconf -e "smtpd_recipient_restrictions=reject_non_fqdn_recipient,reject_unknown_recipient_domain,reject_unverified_recipient"
fi

# Use 587 (submission)
sed -i -r -e 's/^#submission/submission/' /etc/postfix/master.cf

/usr/sbin/postfix -c /etc/postfix start
