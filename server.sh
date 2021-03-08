#!/usr/bin/bash

declare -r CR=$'\r'
declare -r LF=$'\n'
declare -r CR_LF="${CR}${LF}"

declare -r DEBUG=1

declare -A function_dictionary=(
    [is_file]=is_file
    [login]=login
)

serve() {
    nc --listen --keep-open --wait 1 0.0.0.0 7999 --sh-exec "./server.sh process"
}

log() {
    if [ $DEBUG = 1 ]; then echo "$1" >&2; fi
}

process() {
    IFS=$'\n' 

    # STDIN -> request_headers
    get_request_headers

    # request_headers -> request_type, request_body
    get_request_body

    # request_headers -> requested_resource
    handle_requested_resource

    unset IFS
}

get_request_headers() {
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
}

get_request_body() {
    request_type="$(echo "${request_headers[0]}" | cut -d" " -f1)"
    if [ "$request_type" = "POST" ]
    then
        post_length=0
        for i in "${request_headers[@]}"
        do
            header=$(cut -d":" -f1 <<< "$i")
            if [ "$header" = "Content-Length" ]
            then
                post_length=$(echo "$i" | cut -d":" -f2 | tr -d "$CR" | tr -d "$LF" | tr -d ' ')
                break
            fi
        done

        IFS= read -n "$post_length" request_body  
    fi
}

handle_requested_resource() {
    resource="$(echo "${request_headers[0]}" | cut -d" " -f2)"

    requested_resource="./app$resource"
    if [ -f "$requested_resource" ]
    then
        ${function_dictionary["is_file"]}
    fi

    requested_resource="${resource:1}"
    if [ ${function_dictionary["$requested_resource"]+_} ]
    then
        ${function_dictionary["$requested_resource"]}

    else
        version="HTTP/1.1 404 NOT FOUND"
        requested_resource="./app/404.html"
        ${function_dictionary["default"]}
    fi
}

set_response_content_type() {
    escape=false

    case "$1" in
        "html")
            content_type="Content-Type: text/html"
            ;;
        "css")
            content_type="Content-Type: text/css"
            ;;
        "js")
            content_type="Content-Type: text/javascript"
            ;;
        "ico")
            content_type="Content-Type: image/x-icon"
            escape=true
            ;;
        "png")
            content_type="Content-Type: image/png"
            escape=true
            ;;
        "jpg" | "jpeg")
            content_type="Content-Type: image/jpeg"
            escape=true
            ;;
        "mp4")
            content_type="Content-Type: video/mp4"
            escape=true
            ;;
        *)
            content_type="Content-Type: text/plain"
            ;;
    esac
}

get_requested_content() {
    if [[ "$1" = true ]]
    then
        content=$(cat "$2" | sed 's/\\/\\\\/g' | sed 's/%/%%/g' | sed 's/\x00/\\x00/g')
    else
        content=$(cat "$2")
    fi
    content_length="Content-Length: ${#content})"
}

set_response_headers() {
    version="HTTP/1.1 200 OK"
    date="Date: $(date)"
    connection="Connection: Closed"
    response_headers="${version}$CR_LF${date}$CR_LF$1$CR_LF$2$CR_LF${connection}"
}

build_response() {
    response="$1$CR_LF$CR_LF$2"
}

send_response() {
    if [[ $1 = true ]]
    then
        printf "$2"
        exit

    else
        echo "$2"
        exit
    fi
}

is_file() {
    # -> content_type, escape
    extension="${requested_resource##*.}"
    set_response_content_type "$extension"

    # -> data | ESCAPED data, content_length
    get_requested_content "$escape" "$requested_resource"

    # -> response_headers
    set_response_headers  "$content_type" "$content_length"

    # -> response
    build_response "$response_headers" "$content"

    # -> ECHO data | PRINTF data 
    send_response "$escape" "$response"
}

send_html() {
    content="$1"
    content_length="${#content}"

    set_response_content_type "html"
    set_response_headers "$content_type" "$content_length"
    build_response "$response_headers" "$content"

    send_response false "$response"
}

login() {
    if [ "$request_type" = "GET" ]
    then
        requested_resource="./app/login.html"
        is_file

    else
        username=$(echo -n $request_body | cut -d'&' -f1 | cut -d'=' -f2)
        password=$(echo -n $request_body | cut -d'&' -f2 | cut -d'=' -f2)

        log "$username trying to log in with $password"

        content="<h1>hello, $username!</h1>"
        send_html "$content"
    fi
}

"$@"
