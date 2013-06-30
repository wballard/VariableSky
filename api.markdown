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

It is important to realize that this callback will fire every time the
link changes, this is how values are replicated.

Snapshot is a JavaScript value, and this includes `undefined`, which you
can think of as like a `404`, and `null`, which is when you actually
`save` a `null` value.

Take snapshot and use it in your client program. This callback is the
place where you move data coming in from the server into the UI
framework you are using.

####Return Notes
The return value of this function is a `Link`, not actual data. Holding
on to this link is important, as it contains the magic to automatically
refresh snapshot values supplied by the callback. Even if there is no
data at the requested `href`, a `Link` is returned. Variable Sky
never gives a `404`, it gives a `Link`, and you can always `save` to it.
The Variable Sky server will create objects as needed to make sure your
data is reachable.

If you let go of this `Link`, you disconnect your `callback` from the
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

## StringLink
Strings are a bit special, in that you will often want to edit parts of
them, as well as allow users to concurrently edit them to allow
collaboration. Variable Sky strings can be used as shared workspaces for
multiple users to collaborate in real time.

## ArrayLink
Arrays allow you to do partial updates, more efficient then updating the
entire array all the time, and more concurrent. You can of course `save`
them, and re-write the entire array, but the link itself supports the
basic JavaScript array mutators.

ArrayLink does this in a novel way, the `snapshot` handed to you is a
modified JavaScript Array, proxied to intercept the following methods:

* splice
* sort
* reverse
* push
* pop
* shift
* unshift

Collectively 'the mutators', methods that modify an array in place. This
proxies array transmits these operations on to the server automatically.
Arrays coming back from Variable Sky are special in this way, and simple
to use -- they works just like normal arrays.


