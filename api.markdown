---
layout: default
title: API
---

## Errors
The Variable Sky API isn't about the DOM, it's about data, and as such
follows the Node.js convention of `(error, arguments)` to callbacks.

Error objects will always have at least these properties:

|Property|Notes|
|---------|-----|
|name|Tired of goofy error numbers? Indeed, all errors will have a name.|
|message|This is a longer, nerdy, descriptive string that may help programmers, and will certainly confuse users if you show it to them.|

## Values
_Any JavaScript value_ means any value that can be successfully
transmitted over JSON. That's almost the same thing as _any value_, but
I'm sure if you try you can cook up values that have cycles that just
don't serialize.

## VariableSky
This is the main object. There is no need to `new` it, you
just call methods on it. This is how you hook a client to a server.

### link()
Connect to Variable Sky via an `href`, linking to a local variable in
your client program via a callback.

In a typical program, you will have a lot of calls to `link` in order to
get different pieces of data. In order to unlink, just let go of the
returned `Link` object.

|Parameter|Notes|
|---------|-----|
|href|This is an URL to your Variable Sky server, pointing to the desired data.|
|callback|This function is called once the data is returned to you.|
|returns|A `VariableLink` or `VariableArray`.|

####Callback Notes
|Parameter|Notes|
|---------|-----|
|error||
|snapshot|A plain old JavaScript value, returned from Variable Sky. This is your data, use it.|

It is important to realize that this callback will fire just once.

Snapshot is a JavaScript value, and this includes `undefined`, which you
can think of as like a `404`, and `null`, which is when you actually
`save` a `null` value.

Take snapshot and save it into a variable in your client program, just
`x = snapshot;` will do it.

Internally, the `Link` tracks the `snapshot` reference, and will update
it automatically. Having another reference to this value will work just
fine, after all another `var` just points to the same contents.
**However** if you clone this value in any way, it unhooks from the
server. You can do this on purpose, but just make sure you did it on
purpose.

While linked, `snapshot` will update automatically with:

* Changes made by the server
* Changes saved by other clients

####Return Notes
The return value of this function is a `Link`, not actual data. Holding
on to this link is important, as it contains the magic to automatically
refresh snapshot values supplied by the callback. Even if there is no
data at the requested `href`, a `Link` is returned. Variable Sky
never gives a `404`, it gives a `Link`, and you can always `save` to it.
The Variable Sky server will create objects as needed to make sure your
data is reachable.

If you let go of this `Link`, you disconnect your `snapshot` from the
server.

### authenticate()
Authenticate binds an authentication token, which forms a security
session between client and server. On the server, you validate or reject
the token as needed. Variable Sky itself doesn't provide authentication,
just events to let you hook in authentication systems, such as `OpenID`,
`OAuth`, or `LDAP`.

|Parameter|Notes|
|---------|-----|
|token|Any JavaScript value, this will be sent to the server|
|callback|This function is called after the server validates or rejects the token|

####Callback Notes
|Parameter|Notes|
|---------|-----|
|error|No news is good news, if the error is blank, you are authenticated|
|info|Optional additional info from the server|

### unauthenticate()
End a security session between client and server in order to 'log out'.

|Parameter|Notes|
|---------|-----|
|callback|This function is called after the server ends the security session|

####Callback Notes
|Parameter|Notes|
|---------|-----|
|error|Every hear of a logout failing? Me either.|
|info|Optional additional info from the server|

## Link
When you call `link`, you get a `Link`. This object maintains the
connection between your client and the server, so you need to hang on to
it in order to have snapshots update automatically.

### save()
Save a new value to a link, this replaces the existing value, notifies
the server, and then replicates to all clients.

You can pass any JavaScript value or a `null`, this updates the link and
all the way down its children. By making 'deep links' into the data, you
can do selective updates of individual properties, and with 'shallow
links' you can do bulk updates of whole objects.

|Parameter|Notes|
|---------|-----|
|value|Any JavaScript value, just a variable, no need to JSON it|
|callback|This function is called after the server saves|

####Callback Notes
|Parameter|Notes|
|---------|-----|
|error|If you get an error, the value didn't save|

### remove()
Remove lets you undefine a variable on the server. This is different
than `null`.

|Parameter|Notes|
|---------|-----|
|callback|This function is called after the server saves|

####Callback Notes
|Parameter|Notes|
|---------|-----|
|error|If you get an error, the value didn't get removed|

## VariableLink
## VariableLinkArray
### splice
### push
### pop
### shift
### unshift
### reverse


