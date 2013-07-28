---
layout: default
title: Data Mode
---

# Overview
Variable Sky is just that: JavaScript variables in the sky. The server
and your client application use the same data. Variable Sky keeps them
in synch.

This builds on a basic assumption that JavaScript variables can be
transported via JSON, and accessed with a simple `.` syntax
`variable.property` or `variable.array_property[0]` or
`variable['property']`. Simply think of `.` as `/` and it all comes
together to have fully addressable data.

So, the example:

```javascript
var people = {
  'a':
    {
      firstName: 'Fred',
      lastName: 'Star'
    },
  'b':
    {
      firstName: 'Bob',
      lastName: 'Moon',
      friends: ['a']
    }
};
```

OK -- just some plain old data. Now, Variable Sky creates a server that
holds these variables in a server so they can be shared and synched
between clients. So from above, if you want to get *Fred*

```
people.a.firstName
```

Pretty much what you would expect.

Just a tiny bit different than plain JavaScript, `.` is the delimiter,
and any name is allowed. So, you can have a path like this to point into
an array:

```
people.012.name
```

Normal JavaScript would forbid you to have an int as a name, but we know
what you meant, and will translate that into a string key `["012"]`
becuase, well, you typed a string with `.` in it.

# Philosophy
The idea is that a Variable Sky server is literally one big shared
JavaScript variable, starting from a root, and contains any values
you can ship over JSON. You `link` to this data, which causes it to
replicate between all attached clients and the server.

In practice, this lets you define records, stored by key in a JavaScript
hash, then look those records up, modify them, and save them back to the
server easily. This direct access model matches how most folks program:

* Grab a thing by key
* Work on it
* Save it

In addition, arrays are supported, allowing you to add, remove, and
replace items in an array without loading or saving the entire array. If
you think about your applications, this makes sense. You have:

* Stuff
* With keys
* And lists of stuff

And that's about it, because that is it -- that's all you can make in
JavaScript. So Variable Sky lets you store it without needing another
data model. And it lets you *share* it between multiple clients to
create real time single page apps with automatic data replication. Every
client sees the data changes automatically.
