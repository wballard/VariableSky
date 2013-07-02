---
layout: default
title: Data Mode
---

# Overview
Variable Sky is just that: JavaScript variables in the sky. The basic
idea is a correspondence between JavaScript variables and `href`.

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
between clients. You get at data thus:

|HREF|Value|
|----|-----|
|/people/1/firstName|Fred|
|/people/b|{firstName: 'Bob', lastName: 'Moon'}|
|/people/b/friends[0]|a|

# Philosophy
The idea is that a Variable Sky server is literally one big shared
JavaScript variable, starting from a root `/`, and contains any values
you can ship over JSON.

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
create real time single page apps.
