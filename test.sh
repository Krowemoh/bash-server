#!/usr/bin/bash

declare -r CR=$'\r'
declare -r LF=$'\n'
declare -r CR_LF="${CR}${LF}"

declare -r DEBUG=1

log() {
    if [ $DEBUG = 1 ]
    then 
        echo "$1" >&2; 
    fi
}

serve() {
    nc --listen --keep-open 0.0.0.0 7999 --sh-exec "./test.sh process"
}

get_request_headers() {
    request_headers=()

    while true
    do
        read header
        log "$header"
        if [ "$header" = $CR_LF ]
        then
            break
        fi
        request_headers=("${request_headers[@]}" "$header")
    done
}

handle_requested_resource() {

    regexp=".* (.*) HTTP"
    [[ "${request_headers[0]}" =~ $regexp ]]

    resource="${BASH_REMATCH[1]}"

    requested_resource="./app$resource"
    if [ -f "$requested_resource" ]
    then
        cat "$requested_resource"
    fi
}

process() {
    IFS=$LF 

    get_request_headers

    handle_requested_resource
}

$1
