# Simple cURL testing scripts

POSIX shell scripts for testing HTTP API endpoints with cURL.

Installing [`jq`](https://jqlang.org/) is required to get testing to
fully work.

**WIP.** You can use this, but you can't complain about it. 😊

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

### `get_json`

Perform a `GET` request with a JSON response.

```
get_json \
    message \
    URL \
    expected_code \
    expected_response
```

```
get_json "Getting single user" \  # message
    http://localhost/users/12 \   # URL
    200 \                         # Expected status
    '{"id":12, "name":"Athena"}'  # Expected response
```

### `post_json`

Perform a `POST` JSON request with a JSON response.

```
post_json \
    message \
    URL \
    payload \
    expected_code \
    expected_response
```

```
post_json "Adding single user" \  # message
    http://localhost/users \      # URL
    201 \                         # Expected status
    '{"status": "ok"}'            # Expected response
```

## `extract_field`

Simple interface for trying to pull a field name out of the response.

```
extract_field property
```

```
# response: {"id": 12, "name": "foo"}

id_value=$(extract field "id")

echo $id_value   # 12
```

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

Getters:

* `request`: contains the most recent request
* `response`: contains the most recent response
* `http_status`: contains the most recent HTTP response code

Setters:

* `show_request`: if non-zero, the request payload is printed with each
  POST request.
* `show_response`: if non-zero, the response payload is printed with
  each request.

## Comparisons

JSON comparisons are done with `jq`.

The order of the properties in the object doesn't matter.

Regexes can be used in strings.

Missing fields are ignored (i.e. expected results can be a subset of
actual results and still pass).

When matching arrays, all elements of the result array should match the
pattern in the expected array. For example, this will match true if all
elements in the response match the expected pattern:

```
[{"name": "foo.*"}]
```

That is, it will succeed if the result is an array where all elements
have a `name` property that starts with `foo`.

## Example Driver

See [`curltest_example.sh`](curltest_example.sh)

