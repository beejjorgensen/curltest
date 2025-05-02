#!/bin/sh

. ./curltest.sh

#show_response=1
show_request=1

PORT=8086
URL="http://localhost:${PORT}"

# ---------------------------------------------------------

post_json "Posting new message" $URL/messages '{
        "message": "something"
    }' \
    201 '{"id":".*","links":{"self":"/messages/.*"}}'

id=$(extract_field "id")

printf "New message id was %s\n" "$id"
printf "New message links %s\n" "$(extract_field 'links')"

# ---------------------------------------------------------

for i in $(seq 2 5); do
    post_json "Posting new message $i" $URL/messages '{
            "message": "something '$i'"
        }' \
        201 '{"id":".*","links":{"self":"/messages/.*"}}'
done

# ---------------------------------------------------------

get_json "Getting non-existent message" $URL/messages/999999999999999999999999 \
    404 '{"error":"Message 999999999999999999999999 not found"}'

printf "HTTP status: %s\n" "$http_status"
printf "Request: %s\n" "$request"
printf "Response: %s\n" "$response"

# ---------------------------------------------------------

get_json "Getting existent message" $URL/messages/$id \
    200 '{"id":"'$id'","message":"something","links":{"self":"/messages/'$id'"}}'

printf "message: %s\n" "$(jq_query .message)"

# ---------------------------------------------------------

get_json "Testing message contents (deliberate fail)" $URL/messages/$id \
    999 '{"id":"'$id'","message":"BADNESS","links":{"self":"/messages/'$id'"}}'

# ---------------------------------------------------------

get_json "Getting all messages" $URL/messages \
    200 '[{"id":".*","message":"something","links":{"self":"/messages/.*"}}]'

