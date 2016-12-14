# docker-postfix
Simple postfix relay host for your Docker containers. Based on Alpine Linux.

ENV vars
$HOSTNAME= Postfix myhostname
$RELAYHOST= Host that relays your msgs
$MYNETWORKS= allow domains from per Network ( default 127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 )
$ALLOWED_SENDER_DOMAINS = domains sender domains
