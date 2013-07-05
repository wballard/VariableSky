---
layout: default
title: API
---

## Overview

### Errors
The Variable Sky API isn't about the DOM, it's about data, and as such
follows the Node.js convention of `(error, arguments)` to callbacks.

Error objects will always have at least these properties:

|Property|Notes|
|---------|-----|
|name|Tired of goofy error numbers? Indeed, all errors will have a name.|
|message|This is a longer, nerdy, descriptive string that may help programmers, and will certainly confuse users if you show it to them.|

### Values
_Any JavaScript value_ means any value that can be successfully
transmitted over JSON. That's almost the same thing as _any value_, but
I'm sure if you try you can cook up values that have cycles that just
don't serialize.


## VariableSky
This is the main object exposed by the client library. There is no need
to `new` it, you just call methods on it. This is how you hook a client
to a server.

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


## Server
This is the main object you create on the server, `new` it.

|Parameter|Notes|
|---------|-----|
|options|An option hash|

|Option|Notes|
|---------|-----|
|storageDirectory|Root directory for snapshots and journals, this is used to maintain state|

### Hooks
On the server, you can _hook_ the events. This is similar to setting up
routes on an HTTP server, and gives you the chance to intercept:

* Reads, before they go back to a client
* Writes, before they are saved into Variable Sky

And, it is a great place for you to hook in other systems including:

* REST APIs
* Web services
* SQL databases
* Sending email
* Custom security schemes

Things to know about hooks:

* Hooks are always on an `href` or wildcard pattern
* You can have multiple hooks of each type on an `href`
* If you have multiple hooks of each type on the same `href`, they fire
  in the order they are attached

A hook is a function, with the following parameters.

|Parameter|Notes|
|---------|-----|
|context|A `ServerContext`, containing data about the operation|
|next|A callback to fire the next hook in the chain, or to finish|

Inside the hook function you:

1. Use the `context` to decide what to do
2. Modify `context` as needed
3. Call `next` to signal that you are done, remember this is mandatory

All of the hook event methods expose the same signature:

|Parameter|Notes|
|---------|-----|
|href|A path, or regular expression, that matches against a `Link.href`|
|hook|A hook function|
|returns|The same `Server`, to allow chaining|

### link()
Hook data reads, this allows you to modify data before it is sent out to
clients. The thing here is to change what is in `context.val`, this is
read interception.

```javascript
server.link('/myrecord', function(context, next){
  //force the data to be what you like
  context.val = "Totally taking over";
});
```

### saved()
Hook data saves, this allows you to modify data before it is saved.

### removed()
Hook data removes, this allows you to react before data is removed.

### mutated()
Hook array mutation

### rest
This is `connect` middleware, `use` this to have the rest API connected.

```javascript
var app = require('express')(),
  sky = require('variablesky'),
  skyserver = new sky.Server();

app.use(skyserver.rest);
```

### listen()
This is how you set up a Variable Sky server inside a Node.js process.
Using `express`, you embed Variable Sky into a server process. This lets
you serve static content, a site, the Variable Sky server, and
importantly the client library that lets an application connect.

|Parameter|Notes|
|---------|-----|
|server|An http server object, this provides network transport|
|returns|`this`, to allow chaining|

### Sample Server
An example, verb basic server:

```javascript
var app = require('express')()
  , server = require('http').createServer(app)
  , sky = require('variablesky'),
  , skyserver = new sky.Server();

//hook sockets up
skyserver.listen(server);

//normal web service
server.listen(80);

//a static web page
app.get('/', function (req, res) {
  res.sendfile(__dirname + '/index.html');
});

//hook behavior
sky.data("/sample", function(context, response, next){
  //a very simple example of always having a defaut value
  response = response || {};
  next();
}).saved("/sample", function(context, response, next){
  //you can get at the previous and current values
  console.log(context.link.prev());
  console.log(context.link.val());
  //a modify timestamp
  response.at = Date.now();
  next();
});
```

And a very basic client:

```html
<script src="/variablesky/client.js"></script>
<script>
  var sample = VariableSky.link("/sample");
  sample.on("data", function(error, snapshot){
    console.log(error, snapshot);
  )};
  sample.save("Hi mom!");
</script>
```


## HookContext
Server hooks get an instance of this passed to their hook function.

### href
The `href` of the data being hooked, this will be from `/`, not
including host, protocol, or port and is split into an array

### val
This is the value the command is working on, and you can modify it to
change the final result of the command as needed.

#### data
The value currently stored in the server, change this value to intercept
what is sent to the client.

#### saved
The original value sent in by the client.

#### removed
`undefined`, there is no `val` for a `removed`.

#### mutated
In this case, `val` contains the arguments that will be passed to the
eventual array `splice`. This lets you redefine the splice.

|Property|Notes|
|-----|-----|
|index|Start modifying the array at this index|
|howMany|Remove this many elements|
|elements|Insert this array of elements after removing. If emtpy, we are just removing elements|

### prev
Get the previous value of of the data before this current hook sequence
started.

For `data`, this will be equal to `val` since there is no change
pending.

### link()
Return a `Link` to other data on the server. As we are _in_ the server
while the hook is running, `val` is already defined and there is no need
to hook up for events.

Remember that this gives you a snapshot, modifying the contents of `val`
doesn't save anything to the server.

### parent()
Creates a `ServerContext` for the containing parent. Use this to go 'up
and over' to get at more data.

When you ask for a parent, `prev` will hold the actual stored value on
the server, but `val` will not change.

### abort()
Abort the processing of hooks, raising an error, and blocking the
operation from modifying server state.

|Parameter|Notes|
|---------|-----|
|error|An error identifier|
|message|An error message|


## Link
When you call `link`, you get a `Link`. This object maintains the
connection between your client and the server, so you need to hang on to
it in order to have snapshots update automatically.

### href
The `Link` is to this `href` path. Used for self reference.

### val
Get the current value of `Link`, which may be `undefined` if data hasn't
made it from the server yet. This isn't a substitute for event handling,
but just a convenience to get at the current value.

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

### search()
Starting from this link, do a full text search query. This will return
matches, which are themselves links to matched data.

By default, all data in Variable Sky is full text indexed. You search
from a given `Link` as a root, and all matching data is returned as
links down to the property level. Using these links you can _back up_
the `href` to logically containing objects as needed.

|Parameter|Notes|
|---------|-----|
|query|A full text search expression|

####Callback Notes
|Parameter|Notes|
|---------|-----|
|error||
|matchingLinks|An array of `Link` objects matching the query|

### parent()
Returns a `Link` representing the parent.

### child()
Returns a `Link` to a child. Sometimes you want the child data, just use
`.` or `[]`, sometimes you want a link to the child, for example setting
up multiple bound records in an array.

|Parameter|Notes|
|---------|-----|
|path|A relative path, delimited by /|

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


## ArrayLink
Arrays allow you to do partial updates, more efficient then updating the
entire array all the time, and more concurrent. You can of course `save`
them, and re-write the entire array, but the link itself supports the
basic JavaScript array mutators.

### mutators
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

### set()
In addition to the default mutators, you can call `set` to replace a
single element of an array, avoiding rewriting an entire array to just
update one object.

|Parameter|Notes|
|---------|-----|
|index|Change the element at this index|
|value|Put this value into the array|

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
var sampleArray;
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


## StringLink
Strings are a bit special, in that you will often want to edit parts of
them, as well as allow users to concurrently edit them to allow
collaboration. Variable Sky strings can be used as shared workspaces for
multiple users to collaborate in real time.

### concurrentEdit()
Enable concurrent editing on a user interface element. Simply call this
method, and your users will engage in real time concurrent editing.

|Parameter|Notes|
|---------|-----|
|element|An editable DOM element|

`element` can be an `INPUT`, `TEXTAREA`, `CodeMirror`, or `ACE`.


