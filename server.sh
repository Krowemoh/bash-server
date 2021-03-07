#!/usr/bin/bash

declare -r CR=$'\r'
declare -r LF=$'\n'
declare -r CR_LF="${CR}${LF}"

serve() {
    nc --listen --keep-open --wait 1 0.0.0.0 7999 --sh-exec "./server.sh process"
}

process() {
    IFS=$'\n' 

    request_headers=()

    while true
    do
        read -a header
        if [ "$header" = $CR_LF ]
        then
            break
        fi
        request_headers=("${request_headers[@]}" "$header")
    done

    request_type="$(echo "${request_headers[0]}" | cut -d" " -f1)"
    requested_resource=".$(echo "${request_headers[0]}" | cut -d" " -f2)"

    if [ "$request_type" = "POST" ]
    then
        post_length=0
        for i in "${request_headers[@]}"
        do
            header=$(cut -d":" -f1 <<< "$i")
            if [ "$header" = "Content-Length" ]
            then
                echo "Breaking" >&2
                post_length=$(echo "$i" | cut -d":" -f2 | tr -d " ")
                break
            fi
        done
        IFS= read -a body -n "$post_length" 
        echo "$body" >&2
    fi

    version="HTTP/1.1 200 OK"
    date="Date: $(date)"
    connection="Connection: Closed"

    if [ "${requested_resource: -1}" = "/" ]
    then
        requested_resource="${requested_resource}index.html"
    fi


    if [ ! -f "$requested_resource" ]
    then
        version="HTTP/1.1 404 NOT FOUND"
        requested_resource="./404.html"
    fi

    extension="${requested_resource##*.}"

    if [ "$extension" = "html" ]
    then
        content_type="Content-Type: text/html"

    elif [ "$extension" = "css" ]
    then
        content_type="Content-Type: text/css"
 
    elif [ "$extension" = "js" ]
    then
        content_type="Content-Type: text/javascript"

    elif [ "$extension" = "ico" ]
    then
        content_type="Content-Type: image/x-icon"

    elif [ "$extension" = "png" ]
    then
        content_type="Content-Type: image/png"

    elif [ "$extension" = "jpg" ]
    then
        content_type="Content-Type: image/jpeg"

    elif [ "$extension" = "mp4" ]
    then
        content_type="Content-Type: video/mp4"

    else
        content_type="Content-Type: text/plain"
    fi

    if [[ "$extension" = "png" || "$extension" = "ico" || "$extension" = "jpg" || "$extension" = "mp4" ]]
    then
        content=$(cat "$requested_resource" | sed 's/\\/\\\\/g' | sed 's/%/%%/g' | sed 's/\x00/\\x00/g')
        content_length="Content-Length: ${#content})"
        response="${version}$CR_LF${date}$CR_LF${content_type}$CR_LF${content_length}$CR_LF${connection}$CR_LF$CR_LF${content}"
        printf "$response"

    else
        content=$(cat "$requested_resource")
        content_length="Content-Length: ${#content})"
        response="${version}$CR_LF${date}$CR_LF${content_type}$CR_LF${content_length}$CR_LF${connection}$CR_LF$CR_LF${content}"
        echo "$response"
    fi

    unset IFS
}

"$@"
