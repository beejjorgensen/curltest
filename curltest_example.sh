#!/bin/sh

. ./curltest.sh

#show_response=1
show_request=1

PORT=8086
URL="http://localhost:${PORT}"

# ---------------------------------------------------------

request_json "Posting new message" POST $URL/messages '{
        "message": "something"
    }' \
    201 '{"id":".*","links":{"self":"/messages/.*"}}'

id=$(extract_field "id")

printf "New message id was %s\n" "$id"
printf "New message links %s\n" "$(extract_field 'links')"

# ---------------------------------------------------------

for i in $(seq 2 5); do
    request_json "Posting new message $i" POST $URL/messages '{
            "message": "something'\''s message #'$i'"
        }' \
        201 '{"id":".*","links":{"self":"/messages/.*"}}'
done

# ---------------------------------------------------------

request_json "Getting non-existent message" GET $URL/messages/999999999999999999999999 \
    "" \
    404 '{"error":"Message 999999999999999999999999 not found"}'

printf "HTTP status: %s\n" "$http_status"
printf "Request: %s\n" "$request"
printf "Response: %s\n" "$response"

# ---------------------------------------------------------

request_json "Getting existent message" GET $URL/messages/$id "" \
    200 '{"id":"'$id'","message":"something","links":{"self":"/messages/'$id'"}}'

printf "message: %s\n" "$(jq_query .message)"

# ---------------------------------------------------------

request_json "Testing message contents (deliberate fail)" GET $URL/messages/$id "" \
    999 '{"id":"'$id'","message":"BADNESS","links":{"self":"/messages/'$id'"}}'

# ---------------------------------------------------------

request_json "Getting all messages" GET $URL/messages "" \
    200 '[{"id":".*","message":"something","links":{"self":"/messages/.*"}}]'

