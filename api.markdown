---
layout: default
title: API
---


## Client Library
A VariableSky server automatically exposes a client library relative to
the socket mount point. Assuming defaults:

```html
<script type="text/javascript" src="%%yourserver%%/variablesky.client"></script>
```
### Errors
The Variable Sky API isn't about the DOM, it's about data, and as such
follows the Node.js convention of `(error, arguments)` to callbacks.

Error objects will always have at least these properties:

|Property|Notes|
|--------|-----|
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

### connect()
Set up a connection from your client to a variable sky server.

|Parameter|Notes|
|---------|-----|
|name|This is the websocket url to the variable sky service, you can leave it blank for defaults|
|returns|A `Client`|

## Client
This object is a connection/session to variable sky. You use it to
`link` data as well as inspect the `val` of replicated data from the
server.

This client tries to stay connected, automatically reconnecting and
restoring all linked state.

### val
The current value of the server, across all active links. Think of this
as a slice of all the data on the server, limited to just the data you
have linked, and replicated.

You *can* update this, but if you don't `save` it, it won't stick and
can be easily updated by other clients and servers.

### link()
Connect to data via an dotted path, linking to a local variable in
your client program via a callback.

In a typical program, you will have a lot of calls to `link` in order to
get different pieces of data.

|Parameter|Notes|
|---------|-----|
|path|A dotted data path, pointing at desired data|
|returns|A `Link`|

####Return Notes
The return value of this function is a `Link`, not actual data. Holding
on to this link is important, as it contains the actual server linkage
that keeps data replicating.

Even if there is no data at the requested path, a `Link` is returned,
with an `undefined` snapshot. You can always `save` to it.

The Variable
Sky server will create objects as needed to make sure your data is
reachable. This means you can *skip* past objects and make deep paths
like `a.b.c`, object `a` and `a.b` will be automatically created if they
do not exist.

### close()
Close off the connection, this will end attempts to reconnect.

### on()
Attach an event handler to this connection.

|Parameter|Notes|
|---------|-----|
|name|The name of the event you want to handle|
|callback|The event handler callback|

Events are listed below. In all cases `this` in the events refers to the
`Client` itself.

#### open
Fired when the connection is open and good to go.

#### close
Fired when the connection is closed and no longer active.

#### error
Fired on any socket reported error.

## Server
This is the main object you create on the server, `new` it.

|Parameter|Notes|
|---------|-----|
|options|An option hash|

|Option|Notes|
|------|-----|
|storageDirectory|Root directory for snapshots and journals, this is used to maintain state|

### hook()
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

* Hooks are always on a data path
* You can have multiple hooks of each type for the same path
* If you have multiple hooks, they fire
  in the order they are attached

A hook is a function, with the following parameters.

|Parameter|Notes|
|---------|-----|
|context|A `HookContext`, containing data about the operation|
|next|A callback to fire the next hook in the chain, or to finish|

Inside the hook function you:

1. Use the `context` to decide what to do
2. Modify `context.val` as needed
3. Call `next` to signal that you are done, remember this is mandatory

All of the hook event methods expose the same signature:

|Parameter|Notes|
|---------|-----|
|event|The named server event to hook|
|path|A path to a variable|
|callback|A hook function|
|returns|The same `Server`, to allow chaining|

Valid values for `event` are below:

#### link
Hook data reads, this allows you to modify data before it is sent out to
clients. The thing here is to change what is in `context.val`, this is
read interception.

```javascript
server.hook('link', 'myrecord', function(context, next){
  //force the data to be what you like
  context.val = "Totally taking over";
  next();
});
```

#### save
Hook data saves, this allows you to modify data before it is saved. Any content
remaining at `context.val` will be actually saved.

```javascript
server.hook('save', 'myrecord', function(context, next){
  //force the data to be what you like
  context.val = {
    name: "Fred",
    type: "Monster"
  };
  next();
});
```

#### remove
Hook data removes, this allows you to react before data is removed. The
most interesting thing to do here is `abort` and prevent a delete.

```javascript
server.hook('remove', 'myrecord', function(context, next){
  //abort and prevent the delete, no need to call next
  context.abort();
});
```

#### splice
Hook in place array modifications.

```javascript
server.hook('splice', 'myarray', function(context, next){
  //this makes a 'push' into a double push
  if (typeof context.val.index == 'undefined') {
    context.val.elements.push('Second Value');
  }
  next();
});
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

### link()
Return a `Link` to other data on the server. Server links are
_superuser_, designed to let you modify any data you see fit in your
server configuration, including changing permissions.

### Sample Server
An example, verb basic server:

```javascript
var app = require('connect')(),
  sky = require('variablesky'),
  skyserver = new sky.Server(),
  server = require('http').createServer(app).listen(9999);

//hook sockets up to both app and server -- it serves a client library
skyserver.listen(app, server);

//a static web page
app.get('/', function (req, res) {
  res.sendfile(__dirname + '/index.html');
});

//hook behavior
sky.hook("link", "sample", function(context, next){
  //a very simple example of always having a defaut value
  context.val = context.val || {};
  next();
}).hook("save", "sample", function(context, next){
  //you can get at the previous and current values
  console.log(context.link.prev);
  console.log(context.link.val);
  //a modify timestamp
  context.val.at = Date.now();
  next();
});
```

And a very basic client:

```html
<script src="/variablesky.client"></script>
<script>
  var conn = VariableSky.connect();
  var sample = conn.link("sample");
  sample.on("link", function(snapshot){
    console.log(snapshot);
  )};
  sample.save("Hi mom!");
</script>
```


## HookContext
Server hooks get an instance of this passed to their hook function.

### val
This is the value the command is working on, and you can modify it to
change the final result of the command as needed.

|Event|Notes|
|-----|-----|
|link|The value currently stored in the server, change this value to intercept what is sent to the client|
|save|The original value sent in by the client|
|remove|`undefined`, there is no `val` for a `removed`|
|splice|See below|

#### splice
In this case, `val` contains the arguments that will be passed to the
eventual array `splice`. This lets you redefine the splice.

|Property|Notes|
|--------|-----|
|index|Start modifying the array at this index, if≈ `undefined` modify at the end of the array|
|howMany|Remove this many elements|
|elements|Insert this array of elements after removing. If emtpy, we are just removing elements|

### prev
Get the previous value of of the data before this current hook sequence
started.

|Event|Notes
|-----|----|
|link|`prev` is the stored server, which will be the same as `val`|
|save|`prev` is the stored server, about to be replaced|
|remove|`prev` is the stored server, about to be removed|
|splice|`prev` is the stored server array, about to be modified|

### link()
Return a `Link` to other data on the server, the same as a client.

Just as a client is in a separate memory space, and updating a linked
snapshot doesn't modify the server unless you `save`, this link hands
you a _clone_.

### abort()
Abort the processing of hooks, raising an error, and blocking the
operation from modifying server state.

All parameters are options, if you just call `abort()` it will fire a
generic error message. That way you won't be able to track down where
you aborted. Use an error message.

|Parameter|Notes|
|---------|-----|
|error|An error identifier|
|message|An error message|


## Link
When you call `link`, you get a `Link`. This object maintains the
connection to data in Variable Sky, so you need to hang on to
it in order to have snapshots update automatically.

All `Link` methods return `this` so you can chain.

### val
The current value of the link, as replicated from the server.

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

####Callback Notes
|Parameter|Notes|
|---------|-----|
|error||
|matchingLinks|An array of `Link` objects matching the query|

### on()
Attach an event handler to this link.

|Parameter|Notes|
|---------|-----|
|name|The name of the event you want to handle|
|callback|The event handler callback|

Events are listed below. In all cases `this` in the events refers to the
`Link` itself.

#### link
Event is fired when any data is changed, including updates you make in
your client, and most importantly updates made by other clients and
servers. This notification is the core of real time updates.

For updates you make, `data` will fire in the same client before `saved`
or `removed`.

|Parameter|Notes|
|---------|-----|
|snapshot|A plain old JavaScript value, returned from Variable Sky, that is the value at the link|

Snapshot is a JavaScript value, and this includes `undefined`, which you
can think of as like a `404`, and `null`, which is when you actually
`save` a `null` value.

Take `snapshot` and use it in your client program. This callback is the
place where you move data coming in from the server into the UI
framework you are using.

When this event fires `snapshot` is identical to `val`.

#### save
Event is fired after `save` reaches the server, and local data is
updated, after `data`. This is interesting becuase other connected
clients and servers may be updating data.

|Parameter|Notes|
|---------|-----|
|snapshot|A plain old JavaScript value, returned from Variable Sky.|

#### remove
Event is fired after `remove` reaches the server.

|Parameter|Notes|
|---------|-----|
|snapshot|A plain old JavaScript value that was removed, returned from Variable Sky.|

#### splice
Event is fired when an array has been in place mutated on the server. This will
fire instead of `data` to avoid sending an entire array. Remember, if
you call `save`, `data` will fire. If you call a mutator, you will get
`splice`.

|Parameter|Notes|
|--------|-----|
|index|Start modifying the array at this index, if≈ `undefined` modify at the end of the array|
|howMany|Remove this many elements|
|elements|Insert this array of elements after removing. If emtpy, we are just removing elements|

This event gives you data about a partial update, with arguments you can
pass to `Array.splice`, the entire updated array is at `Link.val`.

### mutators
Links to arrays exposes the following methods, which have the same meanings as
the default JavaScript methods. The difference is that these methods
notify the Variable Sky server, modify the linked array there, fire
event `data`, then fire an event `splice`, allowing you to apply just
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

```javascript
var sampleArray;
var sampleLink = connection.link("sample");
sampleLink.on("link", function(snapshot){
  //capture a reference to the server array
  sampleArray = snapshot;
  console.log(sampleArray);
});
sampleLink.on("splice", function(index, howMany, elements){
  //here is the fun part, this applies the changes into the array
  console.log(index, howMany, elements);
  console.log(this.val);
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

### concurrentEdit()
Enable concurrent editing of a linked string on a user interface
element. Simply call this method, and your users will engage in real
time concurrent editing.

|Parameter|Notes|
|---------|-----|
|element|An editable DOM element|

`element` can be an `INPUT`, `TEXTAREA`, `CodeMirror`, or `ACE`.

### allow()
Grant a permission to one or more users/groups, see [Security](./security.html).

|Parameter|Notes|
|---------|-----|
|permission|One of read/write/delete/extend|
|ids...|One or more ids of users or groups|

### deny()
Revoke a permission from one or more users/groups, see [Security](./security.html).

|Parameter|Notes|
|---------|-----|
|permission|One of read/write/delete/extend|
|ids...|One or more ids of users or groups|

### takeOwnership()
This only works for the system identity in a server based call, but lets
you reclaim data. So, you have to get at it from a `Server.link()`, not
from a `Client.link()`.

### changeOwnership()
Appoint a user/group as the owner.

|Parameter|Notes|
|---------|-----|
|id|A user or group to own the data|
