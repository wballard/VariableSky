---
layout: default
title: Variable Sky
---

## Problem
You want to make a modern, single page, real time application, and to do
this you need to keep variables and data in synch between multiple
clients and servers.

## Solution
**Variable Sky** is all about building single page
applications with a realtime server designed to easily store and
replicate what you are already working with: _JavaScript variables_.
Variable Sky keeps your JavaScript variables in synch, replicating them
between multiple JavaScript programs, including clients and servers.

To give you a sense, here is a sample of connecting to data:

```javascript
var linkedInfo = null;
var usersLink = VariableSky.link("http://yourserver.io/info");
//event driven data, everything is asynch
usersLink.on("data", function(err, snapshot){
  //snapshot is a 'live' variable linked to the server
  //and will start off undefined, we haven't saved anything yet
  //this callback is fired when the server returns data
  //but this callback is fired every time this variable in the sky changes
  linkedInfo = snapshot;
});

//... your app happens here, pay attention to the variable names
var stuff = {hi: 'mom'};
//yep, the value from stuff
console.log(stuff);
usersLink.on("saved", function(err, snapshot){
  //this callback is fired after the save has reached the server
  //you will still get a "data" event, this event fires when you save
  //data fires when anyone changes data, and always after "data"
  console.log(snapshot);
  console.log(linkedInfo);
});
//send the variable to the sky
usersLink.save(stuff);

```

This is going to print out `{hi: 'mom'}`. Three times. Huh?

* One from `stuff`
* One from `snapshot`
* One from `linkedInfo`, which was updated by the `link` snapshot

OK, so what happened:

* We linked a variable to the server
* We saved data to the server
* Our linked variable updated automatically

And, you can update variables:

```javascript
stuff.from = 'me';
usersLink.save(stuff);
```

No additional callback, the one originally set to `link` will print out
`{hi: 'mom', from: 'me'}`.

This is a lot more exciting when you realize that multiple client
applications can be linked to the same URL, automatically pushing saved
data, allowing you to make real time applications with ease.

A bit more to learn, [Concepts](concepts.html), and [API](api.html).
