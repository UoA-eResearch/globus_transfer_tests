#!/bin/bash

# Run transfers specified in a task file
# Task file syntax: src_endpoint | src_path | dest_endpoint | dest_path | transfer_type (file or folder) | repeats | transfer_options | label
# Output is written to transfer_<current_date_and_time>.log
# Prerequisites:
#   * Globus CLI is installed
#   * Logged in to globus via the CLI (globus login)
#   * Endpoints listed in task file have been activated

mylog() {
    message="$1"
    now=$(date +'%Y/%m/%d %H:%M:%S')
    echo "${now} | ${message}" >> ${log_file}
}

# verify an endpoint has been activated
verify_endpoint_activated() {
    ep_id="$1"
    globus endpoint is-activated ${ep_id} > /dev/null 2> /dev/null
    if [ "$?" -ne "0" ]; then
        mylog "${ep_id} is not activated! This script cannot run!"
        exit 1
    fi
}

# delete a file or a folder via globus
delete() {
    endpoint=$1
    path=$2
    transfer_type=$3
    verify_endpoint_activated ${endpoint}
    if [ "${transfer_type}" == "folder" ]; then
        cmd="globus rm -r -f --notify off ${endpoint}:${path}"
    else
        cmd="globus rm -f --notify off ${endpoint}:${path}"
    fi
    mylog "${cmd}"
    ${cmd} > /dev/null 2> /dev/null
}

# transfer a file or a folder via globus
transfer() {
    src_ep=$1
    src_path=$2
    dst_ep=$3
    dst_path=$4
    transfer_options="$5"
    transfer_type="$6"
    label="$7"
    file_or_folder=$(echo ${src_path} | rev | cut -d/ -f1 | rev)

    verify_endpoint_activated ${src_ep}
    verify_endpoint_activated ${dst_ep}

    cmd="globus transfer --notify off ${transfer_options} ${src_ep}:${src_path} ${dst_ep}:${dst_path}"
    if [ "${transfer_type}" == "folder" ]; then
        cmd="${cmd} --recursive" 
    fi
    mylog "${cmd}"
    task_id=$(${cmd} | grep "Task ID:" | cut -d: -f2 | xargs)
    mylog "Waiting for transfer to finish (Task ID: ${task_id})"
    globus task wait ${task_id}

    tmp_file=$(mktemp)
    globus task show ${task_id} > ${tmp_file}
    status=$(cat ${tmp_file} | grep "Status:" | cut -d: -f2 | xargs)
    bytes_transferred=$(cat ${tmp_file} | grep "Bytes Transferred:" | cut -d: -f2 | xargs)
    bytes_per_second=$(cat ${tmp_file} | grep "Bytes Per Second:" | cut -d: -f2 | xargs)
    rm -f ${tmp_file}

    mylog "RESULT|${task_id}|${src_ep}|${src_path}|${dst_ep}|${dst_path}|${file_or_folder}|${bytes_transferred}|${bytes_per_second}|${transfer_options}|${label}|${status}"
}

# verify a task file has been provided on the command-line
if [ $# != "1" ]; then
    echo "Syntax: $0 <task file>"
    echo "Task file must have the following syntax:"
    echo "src_endpoint_id | src_path | dest_endpoint_id | dest_path | repeats | transfer_options | label"
    exit 1
fi

input_file=$1

# verify provided task file is a file and is readable
if [ ! -f "${input_file}" ] &&  [ ! -r "${input_file}" ]; then
    echo "Input file '${input_file}' does not exist or cannot be read"
    exit 1
fi

log_file="transfer_$(date +'%Y-%m-%d_%H:%M:%S').log"

# read transfers from file
while read line; do
    tmp=$(echo ${line})
    if [[ $tmp == \#* ]] || [ "${#tmp}" == "0" ]; then
        continue
    fi
    src_ep=$(echo $tmp | cut -d\| -f1 | xargs)
    src_path=$(echo $tmp | cut -d\| -f2 | xargs)
    dst_ep=$(echo $tmp | cut -d\| -f3 | xargs)
    dst_path=$(echo $tmp | cut -d\| -f4 | xargs)
    transfer_type=$(echo $tmp | cut -d\| -f5 | xargs)
    repeats=$(echo $tmp | cut -d\| -f6 | xargs)
    transfer_options=$(echo $tmp | cut -d\| -f7 | xargs)
    label=$(echo $tmp | cut -d\| -f8 | xargs)

    if [ "${transfer_type}" != "folder" ] && [ "${transfer_type}" != "file" ]; then
        mylog "WARNING: Wrong transfer type: ${transfer_type}. Only file and folder are allowed. Ignoring request"
	continue
    fi

    # run each transfer for ${repeats} times
    for i in $(seq ${repeats}); do
        delete "${dst_ep}" "${dst_path}" "${transfer_type}"
        transfer ${src_ep} ${src_path} ${dst_ep} ${dst_path} "${transfer_options}" "${transfer_type}" "${label}"
    done
done < ${input_file}


