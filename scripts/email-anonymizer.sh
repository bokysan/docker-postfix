#!/usr/bin/env bash
set -e

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
##
# Email anonymizer is a filter which goes through every line reported in syslog and filters
# out email addresess.
# This ensures that python output buffering is disabled and outputs
# are sent straight to the terminal
##
while ! env PYTHONUNBUFFERED=1 python3 "$SCRIPT_DIR/email-anonymizer.py" "$@"; do
    sleep 1
done