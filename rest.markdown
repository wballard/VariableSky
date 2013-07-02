---
layout: default
title: REST API
---

The REST API provides a simplified interface, intended for use in
debugging and testing. This doesn't give you the events and replication,
but does serve as a pretty nice storage engine.

This API is _pure_ rest in the sense that each `href` is a resource,
there are no parameters.

Security is provided by the `Authorization` header, simply pass a valid
security token as you would to `auth`.

# GET
Returns the content at the specified `href` as `application/json`.

* `404` is returned if there is no content
* `500` is returned if a hook aborts

# PUT
Sets the content at the specified `href` with the content specified. If
the content can be successfully deserialized as JSON, an object will be
set, otherwise the entire content as a string will be set.

* `500` is returned if a hook aborts

# POST
Appends the content to the array at the specified `href`. If the
location does not exist, the array is created. If the location exists,
but is not an array, `405 not allowed` is returned and no data is saved.

* `405` is returned if the location exists but is not an array
* `500` is returned if a hook aborts

# DELETE
Removes the content at the `href`.

* `404` is returned if there is no content
* `500` is returned if a hook aborts

```bash
curl -X POST -H "Content-Type: application/json" -d '{"name":"Ugg","kind":"monster"}' http://yourserver.io/critters
curl http://yourserver.io/critters
[{"name":"Ugg","kind":"monster"}]
curl -X POST -H "Content-Type: application/json" -d '{"name":"Glorn","kind":"monster"}' http://yourserver.io/critters
curl http://yourserver.io/critters
[{"name":"Ugg","kind":"monster"},{"name":"Glorn","kind":"monster"}]
curl -X DELETE -H http://yourserver.io/critters/0
curl http://yourserver.io/critters
[{"name":"Glorn","kind":"monster"}]
curl -X PUT -H "Content-Type: application/json" -d '{glorn@yourserver.io: {"name":"Glorn","kind":"monster"}}' http://yourserver.io/critters
curl http://yourserver.io/critters
{glorn@yourserver.io: {"name":"Glorn","kind":"monster"}}
curl -X POST -H "Content-Type: application/json" -d '{}' http://yourserver.io/critters
405
```
