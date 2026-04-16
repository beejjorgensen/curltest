clean() {
    rm -f "$tempfile"
}

trap clean EXIT

default_content_type=""
default_expected_code=""
default_method=GET
default_verbose=0

total_tests=0
total_passing=0

if command -v tput > /dev/null; then
    CT_YELLOW=$(tput setaf 3; tput bold)
    CT_WHITE=$(tput setaf 7; tput bold)
    CT_RED=$(tput setaf 1; tput bold)
    CT_GREEN=$(tput setaf 2)
    CT_RESET=$(tput sgr0)
else
    CT_YELLOW=""
    CT_WHITE=""
    CT_RED=""
    CT_GREEN=""
    CT_RESET=""
fi

if command -v jq > /dev/null; then
    hasjq=1
else
    hasjq=0
fi

tempfile="curltest.curl.tmp.$$.out"

jq_contains_deep='
def contains_deep(actual; expected):
    actual as $ta | expected as $te |
    if ($ta | type == "string") then
        if (($te | .[0:7]) == "[REGEX]") then
            [$ta | test($te | .[7:])]  # regex
        else
            [($te == "[ANY]" or $ta == $te)]  # number, boolean, or null
        end
    elif (($ta | type == "array") or ($ta | type == "object")) then
        if ($te == "[ANY]") then
            [true]
        else
            ($te | keys | map(contains_deep($ta[.]; $te[.])))
        end
    else
        [($te == "[ANY]" or $ta == $te)]  # number, boolean, or null
    end
    | flatten | all;

contains_deep($actual; $expected)
'

jq_extract='
def extract($key):
  . as $in
  | if $in | type == "array" then
      $in[] | select(has($key)) | .[$key]
    else
      .[$key]
    end;

extract($key)
'

dotenv() {
    if [ $# -gt 0 ]; then
        if [ -f "$1" ]; then
            . "$1"
            return 0
        fi
    else
        for f in .env ../.env ../../../.env; do
            if [ -f "$f" ]; then
                . "$f"
                return 0
            fi
        done
    fi

    warning dotenv: could not locate .env
}

require_jq() {
    if [ $hasjq -eq 0 ]; then
        warning "jq is required--install it before running tests"
        exit 1
    fi
}

warning() {
    printf "%s%s: %s%s\n" "$CT_RED" "$(basename $0)" "$*" "$CT_RESET" 1>&2
}

info() {
    printf "ⓘ %s\n" "$*" 1>&2
}

jq_pp_internal() {
    local json="$1"
    local flags="$2"

    if [ $hasjq -ne 0 ]; then
        printf "%s" "$json" | jq $flags .
    else
        #warning 'jq not found; no pretty-printing for you!'
        printf "%s\n" "$json"
    fi
}
    
jq_pp() {
    jq_pp_internal "$1"
}

jq_ppc() {
    jq_pp_internal "$1" "-c"
}

jq_query() {
    local query="$1"

    if [ $hasjq -ne 0 ]; then
        cat "$tempfile" | jq "$query"
    else
        warning "jq not found; can't run jq queries"'!'
    fi
}

rep_chars() {
    local char="$1"
    local reps="$2"
    local i=0

    while [ $i -lt $reps ]; do
        printf "%s" "$char"
        i=$(($i + 1))
    done
}

status() {
    #echo $*; return
    local cols=$(tput cols)
    local reps=$(($cols - 1))
    local topline=$(rep_chars ═ $reps)
    local botline=$(rep_chars ─ $reps)
    local first=1

    printf "%s╔%s\n" "$CT_WHITE" "$topline"

    for m in "$@"; do
        test -z "$m" && continue

        if [ $first -eq 1 ]; then
            printf "║ %s\n" "$m"
            first=0
        else
            printf "║ %s%s%s\n" "$CT_RESET" "$m" "$CT_WHITE"
        fi
    done

    printf "╙%s%s\n" "$botline" "$CT_RESET"
}

extract_field() {
    local json_field="$1"

    if [ $hasjq -eq 1 ]; then
        jq -r --arg key "$json_field" "$jq_extract" < "$tempfile"
    else
        sed -n 's/.*"'$json_field'":"*\([^,}"]*\).*/\1/p' "$tempfile"|
            sed 's/^ *//' |
            sed 's/ *$//' | head -n 1
        #awk -F"\"${json_field}\":\"" '{print $2}' "$tempfile" | awk -F'"' '{print $1}'
    fi
}

test_expected () {
    # [-j] actualfile expected

    local expected actualfile json_compare=0
    local pass

    while [ $# -gt 0 ]; do
        if [ "$1" = "-j" ]; then
            json_compare=1
        elif [ -z "$expected" ]; then
            expected="$1"
        elif [ -z "$actualfile" ]; then
            actualfile="$1"
        else
            printf "usage: text_expected [-j] expected actualfile\n" >&2
            return 1
        fi
        shift
    done

    if [ -z "$expected" ]; then
        return 0
    fi

    if [ $hasjq -eq 1 -a $json_compare -ne 0 ]; then
        # JSON compare
        jq -n -e \
            --argjson actual "$(cat $actualfile)" \
            --argjson expected "$expected" \
            "$jq_contains_deep" > /dev/null
    else
        # Plain text compare
        printf "%s" "$expected" | diff -q -b - "$actualfile" > /dev/null
    fi

    total_tests=$(($total_tests + 1))

    if [ $? -eq 0 ]; then
        printf "%s✓ PASS: correct response%s\n" "$CT_GREEN" "$CT_RESET"
        total_passing=$(($total_passing + 1))
        return 0
    else
        printf "%s! FAIL: expected %s, got %s %s\n" "$CT_RED" "$expected" "$(cat $tempfile)" "$CT_RESET"
        return 1
    fi
}

test_code() {
    local actual="$1"
    local expected="$2"
    
    if [ -z "$expected" ]; then
        return 0
    fi

    total_tests=$(($total_tests + 1))

    if [ "$actual" -eq "$expected" ]; then
        printf "%s✓ PASS: status %s%s\n" "$CT_GREEN" "$actual" "$CT_RESET"
        total_passing=$(($total_passing + 1))
        return 0
    else
        printf "%s✖ FAIL: expected status %s, got %s%s\n" "$CT_RED" "$expected" "$actual" "$CT_RESET"
        return 1
    fi
}

display_response() {
    local status_code="$1"

    response="$(cat $tempfile)"

    printf "RESPONSE (%s): " "$status_code"
    jq_ppc "$response"
}

request() {
    local log_message url payload expected_response method token
    local content_type="$default_content_type"
    local expected_code="$default_expected_code"

    local json_test_flag methodarg contentarg payloadarg verbose
    local autharg

    while [ $# -gt 0 ]; do
        case "$1" in
            -a|--auth*)
                token="$2"
                shift
                ;;
            -l|--log*-message)
                log_message="$2"
                shift
                ;;
            -m|--method)
                method="$2"
                shift
                ;;
            -c|--content-type)
                content_type="$2"
                shift
                ;;
            -p|--payload)
                payload="$2"
                shift
                ;;
            --expect*-code)
                expected_code="$2"
                shift
                ;;
            --expect*-res*)
                expected_response="$2"
                shift
                ;;
            -v|--verbose|--i-want-more-output-pretty-please)
                verbose=1
                ;;
            -*)
                warning request: unrecognized option $1
                ;;
            *)
                if [ -z "$url" ]; then
                    url="$1"
                else
                    warning request: already specified URL
                fi
        esac
        shift
    done

    if [ -z "$url" ]; then
        warning usage: request url [options]
        return 1
    fi

    if [ -z "$method" ]; then
        if [ -z "$payload" ]; then
            method="GET"
        else
            method="POST"
        fi
    fi

    url="${default_base_url}${url}"

    request="$payload"

    payload_escaped=$(printf "%s" "$payload" | sed "s/'/'\\\\''/g")

    method=$(printf "%s" "$method" | tr '[:lower:]' '[:upper:]')

    status "$log_message" "$method $url"

    case "$method" in
        PUT|PATCH|DELETE)
            methodarg="-X $method"
            ;;
    esac

    case "$method" in
        POST|PUT|PATCH|DELETE)
            contentarg="-H 'Content-Type: $content_type'"
            payloadarg="-d '$payload_escaped'"
            ;;
    esac

    json_test_flag=""
    test "$content_type" = "application/json" && json_test_flag="-j"

    if [ \( ! -z "$verbose" -o $default_verbose -eq 1 \) -a ! -z "$request" ]; then
        printf "REQUEST: "
        if [ $hasjq -ne 0 ]; then
            jq_ppc "$payload"
        else
            printf "%s\n" "$payload"
        fi
    fi

    if [ ! -z "$token" ]; then
        autharg="-H 'Authorization: Bearer ${token}'"
    fi

    cmd="curl -s $autharg $methodarg $contentarg $payloadarg '$url' -o '$tempfile' -w '%{http_code}'"
    #echo ==============================
    #echo $cmd
    #echo ==============================
    http_status=$(eval $cmd)

    if [ $? -ne 0 ]; then
        warning "curl failed--is the server running?"
        exit 2
    fi

    test ! -z "$verbose" -o $default_verbose -eq 1 && display_response $http_status

    test ! -z "$expected_code" && test_code "$http_status" "$expected_code"
    test ! -z "$expected_response" && test_expected $json_test_flag "$expected_response" "$tempfile"
}

summary() {
    local pct color

    status "Summary"

    printf "    Total tests: %d\n" "$total_tests"
    printf "  Passing tests: %d\n" "$total_passing"

    pct=$((100 * $total_passing / $total_tests))
    int_pct=$(printf "%d" "$pct")

    if [ $int_pct -lt 90 ]; then
        color="$CT_RED"
    elif [ $int_pct -ge 90 -a $int_pct -lt 100 ]; then
        color="$CT_YELLOW"
    else
        color="$CT_GREEN"
    fi

    printf "                 %s%d%%%s\n" "$color" "$int_pct" "$CT_RESET"
}
