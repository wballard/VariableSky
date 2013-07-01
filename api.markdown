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
|returns|A `Link`, which may be a subtype.|

####Return Notes
The return value of this function is a `Link`, not actual data. Holding
on to this link is important, as it contains the actual server linkage
that keeps data replicating.

Even if there is no data at the requested `href`, a `Link` is returned.
Variable Sky never gives a `404`, it gives a `Link`, and you can always
`save` to it.  The Variable Sky server will create objects as needed to
make sure your data is reachable.

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
Save a new value to a link, this **replaces** the existing value, notifies
the server, and then replicates to all clients.

You can pass any JavaScript value or a `null`, this updates the link and
all the way down its children. By making 'deep links' into the data, you
can do selective updates of individual properties, and with 'shallow
links' you can do bulk updates of whole objects.

|Parameter|Notes|
|---------|-----|
|value|Any JavaScript value, just a variable, no need to JSON it|

### remove()
Remove lets you _undefine_ a variable on the server. This is different
than `null`.

### on()
Attach an event handler to this link.

|Parameter|Notes|
|---------|-----|
|name|The name of the event you want to handle|
|callback|The event handler callback|

### Event: data
Event is fired when any data is changed, including updates you make in
your client, and most importantly updates made by other clients and
servers. This notification is the core of real time updates.

For updates you make, `data` will fire in the same client before `saved`
or `removed`.

|Parameter|Notes|
|---------|-----|
|error||
|snapshot|A plain old JavaScript value, returned from Variable Sky. This is your data, use it.|

Snapshot is a JavaScript value, and this includes `undefined`, which you
can think of as like a `404`, and `null`, which is when you actually
`save` a `null` value.

Take `snapshot` and use it in your client program. This callback is the
place where you move data coming in from the server into the UI
framework you are using.

### Event: saved
Event is fired after `save` reaches the server, and local data is
updated, after `data`. This is interesting becuase other connected
clients and servers may be updating data. This event gives you the
chance to compare against the last value in `data` if needed.

|Parameter|Notes|
|---------|-----|
|error||
|snapshot|A plain old JavaScript value, returned from Variable Sky.|

### Event: removed
Event is fired when after `remove` resches the server, `data` would have
already fired with an `undefined` `snapshot`.

|Parameter|Notes|
|---------|-----|
|error||


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

ArrayLink exposes the following methods, which have the same meanings as
the default JavaScript methods. The difference is that these methods
notify the Variable Sky server, modify the linked array there, fire
event `data`, then fire an event `mutate`, allowing you to apply just
the delta to a local snapshot. This avoids sending an entire array back
and forth to the server.

* splice
* sort
* reverse
* push
* pop
* shift
* unshift

### Event: mutate
Event is fired when an array has been mutated on the server. This will
fire instead of `data` to avoid sending an entire array. Remember, if
you call `save`, `data` will fire. If you call a mutator, you will get
`mutate`.

|Parameter|Notes|
|---------|-----|
|error||
|mutator|A function that you call over an array in order to synch it up|

The trick is the mutator, the server sends you a function that you call
on your array to catch it up. This allows you to _patch_ an array rather
than re-read the entire thing.

### Example
```javascript
var sampleArray = null;
var sampleLink = VariableSky.link("http://yourserver.io/sample");
sampleLink.on("data", function(err, snapshot){
  //capture a reference to the server array
  sampleArray = snapshot;
  console.log(sampleArray);
});
sampleLink.on("mutate", function(err, mutator){
  //here is the fun part
  mutator(sampleArray);
  console.log(sampleArray);
});
//an initial save, this is an array, a real no fooling array
sampleLink.save([]);
//push a value
sampleLink.push(1);
```

OK, this will print:

```
[]
[1]
```

