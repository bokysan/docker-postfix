# Send rspamd logs to syslog (mail facility) so they flow through the same
# rsyslog pipeline as Postfix -- honouring LOG_FORMAT and ANONYMIZE_EMAILS.
type = "syslog";
facility = "LOG_MAIL";
level = "notice";
systemd = false;
