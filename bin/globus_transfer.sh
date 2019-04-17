#!/bin/bash

# Run transfers specified in a task file
# Task file syntax: src_endpoint | src_path | dest_endpoint | dest_path | repeats | transfer_options | label
# Currently only directory transfers are allowed
# Output are written to transfer_<current_date_and_time>.log
# Prerequisites:
#   * Globus CLI is installed
#   * Endpoints listed in task file have been activated

mylog() {
    message="$1"
    now=$(date +'%Y/%m/%d %H:%M:%S')
    echo "${now} | ${message}" >> ${log_file}
}

delete_folder() {
    url="$1:$2"
    globus ls ${url} > /dev/null 2> /dev/null
    if [ "$?" -eq "0" ]; then
        cmd="globus delete --notify off ${url} --recursive"
        mylog "${cmd}"
        task_id=$(${cmd} | grep "Task ID:" | cut -d: -f2 | xargs)
        status='None'
        while [ "${status}" != "SUCCEEDED" ]; do
            mylog "Waiting for deletion to finish (Task ID: ${task_id})"
            sleep 2
            status=$(globus task show ${task_id} | grep "Status:" | cut -d: -f2 | xargs)
        done
    fi
}

transfer_folder() {
    src_ep=$1
    src_path=$2
    dst_ep=$3
    dst_path=$4
    transfer_options="${5}"
    label="${6}"
    folder=$(echo ${src_path} | rev | cut -d/ -f1 | rev)
    cmd="globus transfer --notify off ${transfer_options} "${src_ep}:${src_path}" "${dst_ep}:${dst_path}" --recursive"
    mylog "${cmd}"
    tmp_file=$(mktemp)
    task_id=$(${cmd} | grep "Task ID:" | cut -d: -f2 | xargs)

    # check for status
    status='None'
    while [ "${status}" != "SUCCEEDED" ] && [ "${status}" != "FAILED" ]; do
        sleep 10
        tmp_file=$(mktemp)
        globus task show ${task_id} > ${tmp_file}
        status=$(cat ${tmp_file} | grep "Status:" | cut -d: -f2 | xargs)
        bytes_transferred=$(cat ${tmp_file} | grep "Bytes Transferred:" | cut -d: -f2 | xargs)
        bytes_per_second=$(cat ${tmp_file} | grep "Bytes Per Second:" | cut -d: -f2 | xargs)
        transfer_rate=$(bc <<< "scale=2; ${bytes_per_second} / 1000 / 1000")
        mylog "Waiting for transfer to finish (Task ID: ${task_id} | Bytes transferred: ${bytes_transferred} | Transfer rate: ${transfer_rate}MB/s)"
        rm -f ${tmp_file}
    done

    mylog "RESULT|${task_id}|${src_ep}|${src_path}|${dst_ep}|${dst_path}|${folder}|${bytes_transferred}|${transfer_rate}MB/s|${transfer_options}|${label}|${status}"
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
    repeats=$(echo $tmp | cut -d\| -f5 | xargs)
    transfer_options=$(echo $tmp | cut -d\| -f6 | xargs)
    label=$(echo $tmp | cut -d\| -f7 | xargs)
    # run each transfer for ${repeats} times
    for i in $(seq ${repeats}); do
        delete_folder "${dst_ep}" "${dst_path}"
        transfer_folder ${src_ep} ${src_path} ${dst_ep} ${dst_path} "${transfer_options}" "${label}"
    done
done < ${input_file}


