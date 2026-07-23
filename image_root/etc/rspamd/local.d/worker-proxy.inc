# Run rspamd_proxy in milter mode so Postfix can talk to it as a milter
# (smtpd_milters = inet:localhost:11332). The proxy scans the message itself
# (self_scan), so no separate "normal" worker is required.
milter = yes;
timeout = 120s;
upstream "local" {
  default = yes;
  self_scan = yes;
}
count = 1;
bind_socket = "localhost:11332";
