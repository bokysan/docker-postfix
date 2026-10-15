#!/usr/bin/env bats

# Print the Dockerfile's VOLUME instruction as a single line, without line continuations
dockerfile_volume() {
	awk '/^VOLUME/{p=1} p{sub(/\\$/, ""); printf "%s", $0} p&&/\]/{exit}' /code/Dockerfile
}

@test "Dockerfile VOLUME is a valid JSON array" {
	local volume="$(dockerfile_volume)"
	echo "VOLUME instruction: ${volume}"

	# Docker silently falls back to shell form for invalid JSON, creating volumes named "[", "]" and "/path,"
	[[ "${volume}" =~ ^VOLUME[[:space:]]+\[[[:space:]]*\"[^\"]+\"([[:space:]]*,[[:space:]]*\"[^\"]+\")*[[:space:]]*\]$ ]]
}

@test "Dockerfile VOLUME includes the Postfix queue" {
	[[ "$(dockerfile_volume)" == *'"/var/spool/postfix"'* ]]
}
