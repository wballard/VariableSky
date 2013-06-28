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
**Variable Sky** is all about building single page applications with a realtime
server designed to easily store what you are already working with
_JavaScript variables_. You make the client app, VarServer does the
rest. Fully open source. No specified UI framework.

To give you a sense, here is a sample of connecting to data:

```javascript
var linkedInfo = null;
var usersLink = VarServer.link("http://yourserver.io/info",
function(err, snapshot){
  //snapshot is a 'live' variable linked to the server
  //and will start off blank, we haven't saved anything yet
  //this callback is fired when the server returns data
  console.log(snapshot);
  linkedInfo = snapshot;
});

//... your app happens here, pay attention to the variable names
var stuff = {hi: 'mom'};
VarServer.save("http://yourserver.io/info", stuff,
function(err, snapshot){
  //this callback is fired after the save has reached the server
  //now -- this has the value from 'stuff'
  console.log(snapshot);
  //yep, the value from stuff
  console.log(stuff);
  //and, what, here is the magic!
  console.log(linkedInfo);
});

```

This is going to print out `{hi: 'mom'}`. Three times.

OK, so what happened:

* We linked a variable to the server
* We saved data to the server
* Our linked variable updated automatically

This is a lot more exciting when you realize that multiple client
applications can be linked to the same URL, automatically pushing saved
data, allowing you to make real time applications with ease.

A bit more to learn, [Concepts](concepts.html), and [API](api.html).
