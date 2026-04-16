#!/bin/sh

. ./curltest.sh

require_jq    # These tests assume jq is installed

#dotenv    # load .env

PORT=${PORT:-8000}  # Use port 8000 unless PORT env var specified

default_content_type="application/json"
default_base_url="http://localhost:$PORT"

#default_verbose=1

#########################################################################
status "Testing Businesses"

request "/businesses" \
    -l "Searching for all businessess" \
    --expect-code 200 \
    --expect-response '{"businesses":[{"id":0,"ownerid":0,"name":"Block 15","address":"300 SW Jefferson Ave.","city":"Corvallis","state":"OR","zip":"97333","phone":"541-758-2077","category":"Restaurant","subcategory":"Brewpub","website":"http://block15.com"},{"id":1,"ownerid":1,"name":"Corvallis Brewing Supply","address":"119 SW 4th St.","city":"Corvallis","state":"OR","zip":"97333","phone":"541-758-1674","category":"Shopping","subcategory":"Brewing Supply","website":"http://www.lickspigot.com"},{"id":2,"ownerid":2,"name":"Robnett'\''s Hardware","address":"400 SW 2nd St.","city":"Corvallis","state":"OR","zip":"97333","phone":"541-753-5531","category":"Shopping","subcategory":"Hardware"},{"id":3,"ownerid":3,"name":"First Alternative Co-op North Store","address":"2855 NW Grant Ave.","city":"Corvallis","state":"OR","zip":"97330","phone":"541-452-3115","category":"Shopping","subcategory":"Groceries"},{"id":4,"ownerid":4,"name":"WinCo Foods","address":"2335 NW Kings Blvd.","city":"Corvallis","state":"OR","zip":"97330","phone":"541-753-7002","category":"Shopping","subcategory":"Groceries"},{"id":5,"ownerid":5,"name":"Fred Meyer","address":"777 NW Kings Blvd.","city":"Corvallis","state":"OR","zip":"97330","phone":"541-753-9116","category":"Shopping","subcategory":"Groceries"},{"id":6,"ownerid":6,"name":"Interzone","address":"1563 NW Monroe Ave.","city":"Corvallis","state":"OR","zip":"97330","phone":"541-754-5965","category":"Restaurant","subcategory":"Coffee Shop"},{"id":7,"ownerid":7,"name":"The Beanery Downtown","address":"500 SW 2nd St.","city":"Corvallis","state":"OR","zip":"97333","phone":"541-753-7442","category":"Restaurant","subcategory":"Coffee Shop"},{"id":8,"ownerid":8,"name":"Local Boyz","address":"1425 NW Monroe Ave.","city":"Corvallis","state":"OR","zip":"97330","phone":"541-754-5338","category":"Restaurant","subcategory":"Hawaiian"},{"id":9,"ownerid":9,"name":"Darkside Cinema","address":"215 SW 4th St.","city":"Corvallis","state":"OR","zip":"97333","phone":"541-752-4161","category":"Entertainment","subcategory":"Movie Theater","website":"http://darksidecinema.com"}],"pageNumber":1,"totalPages":"[ANY]","pageSize":10,"totalCount":"[ANY]","links":{"nextPage":"[REGEX]/businesses\\?page=.*","lastPage":"[REGEX]/businesses\\?page=.*"}}'

request "/businesses/999" \
    -l "Searching for non-existent business" \
    --expect-code 404 \
    --expect-response '{"error":"Requested resource /businesses/999 does not exist"}'

request "/businesses" \
    -l "Posting a new business" \
    -p '{"ownerid":0,"name":"New business 1","address":"123 Sample Ave.","city":"Sample City","state":"OR","zip":"97333","phone":"541-758-9999","category":"Restaurant","subcategory":"Brewpub","website":"http://example.com/1"}' \
    --expect-code 201 \
    --expect-response '{"id":"[ANY]","links":{"business":"[REGEX]/businesses/.*"}}'

id=$(extract_field id)
info "Got ID $id"

request "/businesses/$id" \
    -l "Getting business $id" \
    --expect-code 200 \
    --expect-response '{"reviews":[],"photos":[],"ownerid":0,"name":"New business 1","address":"123 Sample Ave.","city":"Sample City","state":"OR","zip":"97333","phone":"541-758-9999","category":"Restaurant","subcategory":"Brewpub","website":"http://example.com/1","id":'$id'}'

request "/businesses/$id" \
    -l "Updating business $id name" \
    -m "PUT" \
    -p '{"ownerid":0,"name":"Renamed business 1","address":"123 Sample Ave.","city":"Sample City","state":"OR","zip":"97333","phone":"541-758-9999","category":"Restaurant","subcategory":"Brewpub","website":"http://example.com/1"}' \
    --expect-code 200 \
    --expect-response '{"links":{"business":"/businesses/'$id'"}}'

request "/businesses/$id" \
    -l "Getting business $id to look for new name" \
    --expect-code 200 \
    --expect-response '{"reviews":[],"photos":[],"ownerid":0,"name":"Renamed business 1","address":"123 Sample Ave.","city":"Sample City","state":"OR","zip":"97333","phone":"541-758-9999","category":"Restaurant","subcategory":"Brewpub","website":"http://example.com/1","id":'$id'}'

request "/businesses/$id" \
    -l "Deleting business $id" \
    -m "DELETE" \
    --expect-code 204

request "/businesses/$id" \
    -l "Verifying business $id deleted" \
    --expect-code 404 \
    --expect-response '{"error":"Requested resource /businesses/'$id' does not exist"}'

summary
