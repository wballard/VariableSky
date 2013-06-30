---
layout: default
title: Concepts
---

# Overview
Variable Sky keeps variables in synch between multiple clients and
servers. It is at the core a replication solution, keeping variables in
synch.

The data model can be though of as _a giant JavaScript variable in the
sky_. You point into with with Links, update it, and replicate it to
connected clients.

## Clients
Clients are any browser based or JavaScript runtime application, this
includes:

* Classic web sites with HTML/JavaScript/CSS
* AngularJS
* Ember.js
* Phonegap
* Node.js

The requirements are:

* A JavaScript runtime ES5+
* HTTP or WebSocket connectivity

Cutting to it, this means you aren't locked into any specific UI or
application programming framework or style.

## Servers
Servers are `node.js` processes run in any way you see fit. Servers
serve variables from memory, using append only logging. In this way,
Variable Sky is an in memory server, using disk as a backup mechanism.

Multiple servers can be joined to a Variable Sky to scale out.

## Linked Data
Data in Variable Sky is used via links. Clients link to servers to
receive streaming updates of data. Each client keeps a full copy of
their linked data, which make sense -- you are going to be drawing it on
the screen with HTML anyhow. Linked data keeps all the clients up to
date, think of it as continuous replication rather than the detached
replicas you get via a REST API.

By varying how you link, you get a slice of the total data on the server
on each client as needed.

## Data Model
The data model is `JavaScript`, addressed by `href`. This builds on a
basic assumption that JavaScript variables can be transported via JSON,
and accessed with a simple `.` syntax `variable.property` or
`variable.array_property[0]` or `variable['property']`. Simply think of
`.` as `/` and it all comes together to have fully addressable data.

### Link Examples
| JavaScript | HREF | Notes |
| ---------- | ---- | ----- |
| x.a | x/a | Simple `.` to `/` translation |
| x['a'] | x/a | Change the named key a href segment, URL encoded if needed |
| x[0] | x/0 | Array access is just a path with the index number |
| x[0].b | x/0/b| And access on a array member's properties |

## Operations
Operations are the basic units of work that modify linked data. They are
shipped over the network between clients and servers, and are logged to
the append only file that provides a disk based backup on the server.
Operations allow each connected client to effectively replicate the data
on the server to every connected client, as well as to allow servers to
replicate one another to scale out.

Different operations are available based on the type of data.

* All Values
  * `save`: writes a new value, which may be any JavaScript value
  * `remove`: turns a value to undefined, different than saving null
* Arrays
  * `splice`: exactly like JavaScript splice, allows you to update
    arrays in place by index
  * `reverse`: exactl like JavaScript reverse, reverses an array in
    place
  * `push`, `pop`, `shift`, `unshift`: exactly like their JavaScript
    namesakes, these are convenience wrappers around splice

## Events
Events are fired on both clients and servers on every operation. This
allows you to attach callbacks to handle the data change, doing things
like redrawing your HTML, hooking into your framework, or calling
additional logic.

## Hooks
Hooks let you intercept operations, by link, and take additional action.
Think of a href path `/users/*`, with a wildcard. You can hook this
path, supplying a JavaScript handler function. This function gets a
chance to modify the data before it is actually stored. This is a great
place to put validation logic, as well as business application specific
logic that takes place when data changes, such as sending email,
triggering notifications, calling external services, or writing to other
databases.

Hooks can also be installed on links, in this way reads can be
intercepted. This is typically most useful on servers, specifically to
let you translate an href like `/customers/12345` into a query to
another database, perhaps SQL, turning that into JavaScript variables
and returning it to clients. This technique lets you use Variable Sky as
a data hub integrating your existing web services and databases if
needed.

Hooks can be installed on both clients and servers.
