# Simple cURL testing scripts

POSIX shell scripts for testing HTTP API endpoints with cURL.

Installing [`jq`](https://jqlang.org/) is required to get testing to
fully work. Standard packages exist for most Unices.

## Warnings

* The cURL command line uses `eval` due to its complexity. Don't trust user
  input.

## Bugs

* This isn't a particularly strict testing framework and you might get
  false positives or negatives if you're not careful. See the
  [Comparisons](#comparisons) section, below.

* The `jq` scripts aren't well-tested. Might be fragile.

## Usage

Source it into your driver script.

```
. ./curltest.sh
```

## Functions

## `request`

This is the workhorse that you'll call to make requests and check
responses.

See the Comparisons section, below to see how to match expected
responses.

Usage:

```
request [options] URL
```

Options, both shorthand and long forms::

* `-a --auth token`: specify an auth token
* `-l --log message`: give a human-readable message to output for this
  test
* `-m --method method`: specify request verb (`GET`, `POST`, etc.)
* `-c --content-type type`: give the request content type, e.g.
  `application/json`.
* `-p --payload`: Specify the message payload., probably JSON in single
  quotes (`'{"foo": 12}'`)
* `--expected-code`: Expected response HTTP code, e.g. 200, 404, etc.
* `--expected-response`: Expected response, probably JSON in single
  quotes.
* `-v --verbose`: Output the request and response bodies.
                fi
## `extract_field`

Simple interface for trying to pull a field name out of the response.

```
extract_field property
```

For example, for the response `{"id": 12, "name": "foo"}`, we can:

```
id_value=$(extract field "id")

echo $id_value   # 12
```

## `require_jq`

If you call this, the script will only run if `jq` is installed.
Non-trivial response matchers won't behave without it.

It is recommended to install `jq` and call this at the beginning of your
script.

## `jq_query`

Run a `jq` query on the most recent response.

```
jq_query query
```

```
jq_query '.[2].name'   # name property of array element 2

x=$(jq_query '.[2].name')   # assignment to x
```

## `jq_pp`, `jq_ppc`

Use `jq` to pretty print, or pretty-print compactly.

```
jq_pp json
jq_ppc json
```

```
jq_pp '{
    "foo": "bar"}'

jq_ppc '{
    "foo": "bar"}'
```

## Variables

You can set the following variables to control the behavior of curltest.

* `default_content_type`: Content type for requests
* `default_base_url`: Set a URL prefix for all requests, e.g.
  `http://localhost:3490`.
* `default_expected_code`: Expected response code for requests
* `default_method`: Default verb, (`GET`, `POST`, etc.)
* `default_verbose`: Set to 1 to make things more verbose

## Comparisons

If `jq` is installed, it is used for comparisons. Otherwise `diff` is
used in a very naive way. Install `jq`. The rest of this section assumes
you have done so.

When matching against some expected JSON with `request
--expected-response`:

* The order of the properties doesn't matter.
* If the response has more properties than the expected response, they
  are ignored. That is, only properties that exist in the expected
  response are checked for correctness. That is, if the actual response
  is a superset of the expected response, it will pass.
  * An empty array in the expected response will match any array in the
    actual response.

You can match against the string `"[ANY]"` on any property. This will
cause the match to succeed no matter what is in the property.

For example, `{"id":"[ANY]"}` will match all of these:

```
{"id": 12}
{"id": "hey"}
{"id": null}
{"id": [1,2,3]}
{"id": [1,{"foo":"bar"},3]}
```

but will not match:

```
{"foo":"bar"}
```

If the expected property begins with the prefix `[REGEX]`, the remainder
will be matched as a regular expression.

For example, `{"name": "[REGEX]Ab.*"}` will match all names starting
with `Ab`: Abbey, Abbi, Abbie, Abbott, Abby, Abdul, Abdullah, Abe, Abel,
Aberdeen, Abia, Abigail, Abijah, Abimael, Abiona, Abner, Abner, Abra,
Abraham, Abram, Absalom, etc.

## Example Driver

See [`curltest_example.sh`](curltest_example.sh)

## Examples

```
default_base_url="http://localhost:3490"
default_content_type='application/json'

# Post a new business

request "/businesses" \
    -l "Posting a new business" \
    -p '{
          "ownerid": 0,
          "name": "New business 1",
          "address": "123 Sample Ave.",
          "city": "Sample City",
          "state": "OR",
          "zip": "97333",
          "phone": "541-758-9999",
          "category": "Restaurant",
          "subcategory": "Brewpub",
          "website": "http://example.com/1"
        }' \
    --expect-code 201 \
    --expect-response '{"id":"[ANY]","links":{"business":"[REGEX]/businesses/.*"}}'

# Get the `id` field from the last response and store it in `id`

id=$(extract_field id)

# Do a `GET` request of that specific ID:
# (note the `$id` in the request and `"id":'$id'` in the response)

request "/businesses/$id" \
    -l "Getting business $id" \
    --expect-code 200 \
    --expect-response '{
                         "reviews": [],
                         "photos": [],
                         "ownerid": 0,
                         "name":"New business 1", 
                         "address":"123 Sample Ave.",
                         "city":"Sample City",
                         "state":"OR",
                         "zip":"97333",
                         "phone":"541-758-9999",
                         "category":"Restaurant",
                         "subcategory":"Brewpub",
                         "website":"http://example.com/1",
                         "id":'$id'
                       }'
