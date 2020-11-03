#!/usr/bin/env bash

get_postfix_message_id() {
	local log_file=$1
	local message_id=$2
	local postfix_message_id=''
	local result='ko'
	local count=0;
	local max_wait=15
	while [[ $result == 'ko' ]] && [[ $count -lt $max_wait ]]; do
		postfix_message_id=$(cat ${log_file} | grep -E -e 'postfix/cleanup' | cut -d':' -f4- | sed -r -e "s/\s*([^:]+)\s*:\s*message-id=${message_id}/\1/")
		if [[ -n "$postfix_message_id" ]]; then
			result='ok'
		else
			sleep 1
			count=$((count+1))
		fi
	done

	if [[ $count -eq $max_wait ]]; then
		echo >&2 "Message with message-id='${message_id}' not found"
		return 1
	fi

    echo ${postfix_message_id}
    return 0
}

get_smtp_result() {
	local log_file=$1
	local postfix_message_id=$2
	local smtp_result=''
	local result='ko'
	local count=0
	local max_wait=15

	while [[ $result == 'ko' ]] && [[ $count -lt $max_wait ]]; do
		smtp_result=$(cat ${log_file} | grep -E -e 'postfix/smtp\[' | cut -d':' -f4- | sed -r -e "s/${postfix_message_id}:(.*)/\1/g")
		if [[ -n "$smtp_result" ]]; then
			result='ok'
		else
			sleep 1
			count=$((count+1))
        fi
	done

	if [[ $count -eq $max_wait ]]; then
		echo >&2 "Message with postfix id='${postfix_message_id}' not found"
		return 1
	fi

    echo ${smtp_result}
    return 0
}

get_param_value() {
	local smtp_result=$1
	local param_name_to_search=$2
	local params=''
	local param_name=''
	local param_value=''
	local status=''

	local old_ifs=$IFS
	IFS=','
	read -ra params <<< "${smtp_result}"
	IFS=$old_ifs

	for i in "${params[@]}"; do
		param_name=$(echo $i | cut -d'=' -f1)
		param_value=$(echo $i | cut -d'=' -f2)
		if [[ "${param_name}" == "${param_name_to_search}" ]]; then
			status="${param_value}"
			break;
		fi
		echo $i;
	done

	if [[ -z "${status}" ]]; then
		echo "${param_name_to_search} not found!."
		return 1
	fi

	echo "${status}"
	return 0
}