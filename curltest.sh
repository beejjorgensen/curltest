CT_YELLOW=$(tput setaf 3; tput bold)
CT_WHITE=$(tput setaf 7; tput bold)
CT_RED=$(tput setaf 1; tput bold)
CT_GREEN=$(tput setaf 2)
CT_RESET=$(tput sgr0)

warning() {
    printf "%s%s: %s%s\n" "$CT_RED" "$(basename $0)" "$*" "$CT_RESET" 1>&2
}

show_response=0
show_request=0

tempfile="curltest.curl.tmp.$$.out"

jq_matcher='
def deep_match($pattern; $path):
  if ($pattern | type) == "object" then
    . as $actual
    | reduce ($pattern | to_entries[]) as $item (true;
        . and (
            ($actual | has($item.key))
            and ($actual[$item.key] | deep_match($item.value; $path + [ $item.key ]))
        )
      )
  elif ($pattern | type) == "array" then
    . as $actual
    | reduce $pattern[] as $subpattern (true;
        . and ($actual | map(deep_match($subpattern; $path)) | all)
      )
  else
    tostring as $actual_value
    | $actual_value | test($pattern)
  end;

deep_match($expected; [])
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

clean() {
    rm -f "$tempfile"
}

trap clean EXIT

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
    local cols=$(tput cols)
    local reps=$(($cols - 1))
    local topline=$(rep_chars ═ $reps)
    local botline=$(rep_chars ─ $reps)
    local first=1

    printf "%s╔%s\n" "$CT_WHITE" "$topline"

    for m in "$@"; do
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
        awk -F"\"${json_field}\":\"" '{print $2}' "$tempfile" | awk -F'"' '{print $1}'
    fi
}

test_expected () {
    local expected="$1"
    local infile="$2"

    if [ -z "$expected" ]; then
        return 0
    fi

    if [ $hasjq -ne 1 ]; then
        warning "jq not found; testing disabled"
        return 2
    fi

    if jq -e --argjson expected "$expected" "$jq_matcher" < "$infile" > /dev/null; then
        printf "%s✓ PASS: output correct%s\n" "$CT_GREEN" "$CT_RESET"
        return 0
    else
        printf "%s! FAIL: expected %s, got %s %s\n" "$CT_RED" "$expected" "$(cat $tempfile)" "$CT_RESET"
        return 1
    fi
}

test_code() {
    local actual="$1"
    local expected="$2"

    if [ "$actual" -eq "$expected" ]; then
        printf "%s✓ PASS: status %s%s\n" "$CT_GREEN" "$actual" "$CT_RESET"
        return 0
    else
        printf "%s! FAIL: expected status %s, got %s%s\n" "$CT_RED" "$expected" "$actual" "$CT_RESET"
        return 1
    fi
}

show_output() {
    response="$(cat $tempfile)"

    if [ $show_response -ne 0 ]; then
        printf "RESPONSE: "
        jq_ppc "$response"
    fi
}

get_json() {
    local msg="$1"
    local url="$2"
    local code="$3"
    local expected="$4"

    status "$msg" "GET $url"

    http_status=$(curl -s "$url" -o "$tempfile" -w '%{http_code}')

    if [ $? -ne 0 ]; then
        warning "curl failed--is the server running?"
    fi

    show_output

    test_code "$http_status" "$code"
    test_expected "$expected" "$tempfile"
}

post_json() {
    local message="$1"
    local url="$2"
    local payload="$3"
    local code="$4"
    local expected="$5"

    request="$payload"

    status "$message" "POST $url"

    if [ $show_request -ne 0 ]; then
        printf " REQUEST: "
        if [ $hasjq -ne 0 ]; then
            jq_ppc "$payload"
        else
            printf "%s\n" "$payload"
        fi
    fi

    http_status=$(curl -s -H "Content-Type: application/json" \
        -d "$payload" "$url" -o "$tempfile" -w '%{http_code}')

    if [ $? -ne 0 ]; then
        warning "curl failed--is the server running?"
    fi
    show_output

    test_code "$http_status" "$code"
    test_expected "$expected" "$tempfile"
}

if command -v jq > /dev/null; then
    hasjq=1
else
    #warning "please install \`jq\` for full testing"
    hasjq=0
fi
