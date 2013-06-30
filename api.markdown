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
|message|This is a longer, nerdy, descriptive string that may help programmers, and will certainly confuse users.|

## VariableSky
This is the main interface object. There is no need to `new` it, you
just call methods on it.
### link
Connect to Variable Sky via an `href`, linking to a local variable in
your client program.

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

Snapshot is a JavaScript value, and this includes `undefined`, which you
can think of as like a `404`, and `null`, which is when you actually
`save` a `null` value.

Internally, the `Link` tracks the `snapshot` reference, and will update
it automatically. Having another reference to this value will work just
fine, after all another `var` just points to the same contents.
**However** if you clone this value in any way, it unhooks from the
server. You can do this on purpose, but just make sure you did it on
purpose.

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

### authenticate
### unauthenticate
## Link
### save
### remove
## VariableLink
## VariableLinkArray
### splice
### push
### pop
### shift
### unshift
### reverse


