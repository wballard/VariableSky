---
layout: default
title: Variable Sky
---

## Problem
* You want to make a modern, single page, real time application
* You want to pick your UI framework
* You want to avoid server programming and focus on the application
* You don't want to be locked into a proprietary cloud

## Solution
[Variable Sky]({{ site.github }}) is all about building single page applications with a realtime
server designed to easily store what you are already working with
_JavaScript variables_. You make the client app, Variable Sky does the
rest. Fully open source. No specified UI framework.

To give you a sense, here is a sample of connecting to data:

```javascript
var linkedInfo = null;
var usersLink = VariableSky.link("http://yourserver.io/info",
function(err, snapshot){
  //snapshot is a 'live' variable linked to the server
  //and will start off blank, we haven't saved anything yet
  //this callback is fired when the server returns data
  //but this callback is fired every time this variable in
  //the sky changes
  //and we store it each time it changes
  linkedInfo = snapshot;
});

//... your app happens here, pay attention to the variable names
var stuff = {hi: 'mom'};
//yep, the value from stuff
console.log(stuff);
usersLink.save(stuff, function(err, snapshot){
  //this callback is fired after the save has reached the server
  //now -- this has the value from 'stuff' coming back from the sky
  console.log(snapshot);
  console.log(linkedInfo);
});

```

This is going to print out `{hi: 'mom'}`. Three times. Huh?

* One from `stuff`
* One from the `save` `snapshot`
* One from the `linkedInfo`, which was updated by the `link` snapshot

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
