#!/usr/bin/bash

declare -r CR=$'\r'
declare -r LF=$'\n'
declare -r CR_LF="${CR}${LF}"

declare -r DEBUG=1

declare -A function_dictionary=(
    [login]=login
    [signout]=signout
    ["^comics$"]=comics
    ["^comics/(.*)"]=issues
    ["^comics/(.*)/(.*)"]=issue
)

serve() {
    nc --listen --keep-open 0.0.0.0 7999 --sh-exec "./server.sh process"
}

log() {
    if [ $DEBUG = 1 ]
    then 
        echo "$1" >&2; 
    fi
}

check_session() {
    if [ ! -f "./sessions/$session_id" ]
    then
        render_template "./app/login.html"
        send_html "$template"
    fi
}

process() {
    local IFS=$'\n' 

    # STDIN -> request_headers
    get_request_headers

    # request_headers -> request_type, request_body, request_cookies
    get_request_body_cookies

    # request_headers -> requested_resource
    handle_requested_resource
}

get_request_headers() {
    request_headers=()

    while true
    do
        read header
        if [ "$header" = $CR_LF ]
        then
            break
        fi
        request_headers=("${request_headers[@]}" "$header")
    done
}

get_request_body_cookies() {
    request_type="$(echo "${request_headers[0]}" | cut -d" " -f1)"

    post_length=0
    for i in "${request_headers[@]}"
    do
        header=$(cut -d":" -f1 <<< "$i")
        if [ "$header" = "Content-Length" ]
        then
            post_length=$(echo "$i" | cut -d":" -f2 | tr -d "$CR" | tr -d "$LF" | tr -d ' ')

        elif [ "$header" = "Cookie" ]
        then
            regex=".*session_id=(.*);?"
            [[ "$i" =~ $regex ]]
            session_id=$(echo "${BASH_REMATCH[1]}" |  tr -d "$CR" | tr -d "$LF")
        fi
    done

    if [ "$post_length" -ne 0 ] 
    then
        IFS= read -n "$post_length" request_body  
    fi
}

handle_requested_resource() {
    regexp=".* (.*) HTTP"
    [[ "${request_headers[0]}" =~ $regexp ]]

    resource=$(printf "%s" "${BASH_REMATCH[1]}" | sed 's/%20/ /g' | sed "s/%27/'/g")

    requested_resource="./app$resource"
    if [ -f "$requested_resource" ]
    then
        send_file "$requested_resource"
    fi

    requested_resource="${resource:1}"

    for x in "${!function_dictionary[@]}"
    do
        if [[ "$requested_resource" =~ $x ]]
        then
            ${function_dictionary[$x]}
        fi
    done

    render_template "./app/404.html"
    send_html "$template"
}

set_response_content_type() {
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
            ;;
        "png")
            content_type="Content-Type: image/png"
            ;;
        "jpg" | "jpeg")
            content_type="Content-Type: image/jpeg"
            ;;
        "mp4")
            content_type="Content-Type: video/mp4"
            ;;
        *)
            content_type="Content-Type: text/plain"
            ;;
    esac
}

get_requested_content() {
    length=$(stat --printf "%s" "$1")
    content_length="Content-Length: $length"
    content=$(cat "$1" | sed 's/\\/\\\\/g' | sed 's/%/%%/g' | sed 's/\x00/\\x00/g')
}

set_response_headers() {
    version="HTTP/1.1 200 OK"
    date="Date: $(date)"
    connection="Connection: Closed"

    if [ "$cookies" = "" ]
    then
        response_headers="${version}$CR_LF${date}$CR_LF$1$CR_LF$2$CR_LF${connection}"
    else
        response_headers="${version}$CR_LF${date}$CR_LF${cookies}$CR_LF$1$CR_LF$2$CR_LF${connection}"
    fi
}

build_response() {
    response="$1$CR_LF$CR_LF$2"
}

send_response() {
    printf -- "$1$CR_LF"
    exit
}

send_file() {
    # -> content_type
    requested_resource="$1"
    extension="${requested_resource##*.}"
    set_response_content_type "$extension"

    # -> data | content_length
    get_requested_content "$1"

    # -> response_headers
    set_response_headers  "$content_type" "$content_length"

    # -> response
    build_response "$response_headers" "$content"

    # -> ECHO data | PRINTF data 
    send_response "$response"
}

send_html() {
    content="$1"
    content_length="${#content}"

    set_response_content_type "html"
    set_response_headers "$content_type" "$content_length"
    build_response "$response_headers" "$content"

    send_response "$response"
}

render_template() {
    template=$(eval "cat <<- END
    $(cat "$1")
END
")
}

login() {
    if [ "$request_type" = "GET" ]
    then
        content="$(cat ./app/login.html)"
        send_html "$content"

    else
        username=$(echo -n "$request_body" | cut -d'&' -f1 | cut -d'=' -f2)
        password=$(echo -n "$request_body" | cut -d'&' -f2 | cut -d'=' -f2)

        if [ "$password" = "123" ]
        then
            session_id=$(uuidgen)
            touch "./sessions/$session_id"
            cookies="Set-cookie: session_id=$session_id"
        fi
        render_template "./app/account.html"
        send_html "$template"
    fi
}

signout() {
    if [ -f "./sessions/$session_id" ]
    then
        rm "./sessions/$session_id"
        session_id=""
        cookies="Set-cookie: session_id=$session_id"
    fi
    render_template "./app/login.html"
    send_html "$template"
}

comics() {
    check_session
    render_template "./app/comics.html"
    send_html "$template"
}

issues() {
    check_session
    comic_name="${BASH_REMATCH[1]}"
    render_template "./app/issues.html"
    send_html "$template"
}

issue() {
    check_session
    comic_name="${BASH_REMATCH[1]}"
    issue_number="${BASH_REMATCH[2]}"
    render_template "./app/issue.html"
    send_html "$template"
}

"$1"
