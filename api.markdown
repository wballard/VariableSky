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

The good news there is -- you won't be able to save them, so you won't
be able to hurt yourself.


## VariableSky
This is the main object exposed by the client library. There is no need
to `new` it, you just call methods on it. This is how you hook a client
to a server.

### connect()
Set up a connection from your client to a variable sky server.

|Parameter|Notes|
|---------|-----|
|url|This is the websocket url to the variable sky service, you can leave it blank for defaults|
|returns|A `Client`|

## Client
This object is a connection/session to variable sky.

This client tries to stay connected, automatically reconnecting and
restoring all linked state if there are network interruptions.

### val
The current value of the server, across all active links. Think of this
as a slice of all the data on the server, limited to just the data you
have linked, and replicated.

You *can* update this, but if you don't `Link.save()` it, it won't stick and
can be easily updated by other clients and servers.

### client
A string that identifies this client instance. This is default allocated
as a GUID, and is new for each client instance.

You can set this to any string you like, but keep in mind:

* you really need unique client identifiers
* you should set this before using any other client methods

In general, don't set this, just read it. This is settable to support
persistent clients, for example storing a client identifier in local
storage.

### link()
Connect to data via a dotted path, linking to a local variable in
your client program via a callback.

In a typical program, you will have a lot of calls to `link` in order to
get different pieces of data.

|Parameter|Notes|
|---------|-----|
|path|A dotted data path, pointing at desired data|
|callback| (error, snapshot) called each time data changes|
|returns|A `Link`|

####Return Notes
The return value of this function is a `Link`, not actual data. Holding
on to this link is important, as it contains the actual server linkage
that keeps data replicating.

Even if there is no data at the requested path, a `Link` is returned,
with an `undefined` snapshot. You can always `Link.save()` to it.

The Variable Sky server will create objects as needed to make sure your
data is reachable. This means you can *skip* past objects and make deep
paths like `a.b.c`, object `a` and `a.b` will be automatically created
if they do not exist.

### linkToAngular()
Connect to data via a dotted path and inject it into an AngularJS scope.
This provides very automatic data handling, watching for changes from
the server and updating angular, and saving on local changes.

These links hook into the angular lifecycle, and close automatically
on `Scope.$destroy`. No need for you to keep track of them, just do
angular stuff as normal.

You need AngularJs installed to use this method, but Variable Sky
doesn't require or rely on AngularJs, this method turns itself on
automatically.

|Parameter|Notes|
|---------|-----|
|path|A dotted data path, pointing at desired data|
|$scope|An angular `Scope` to receive the data|
|name|A name to store the data on the scope, use this name to bind|
|default|If provided, and the server returns undefined, this will stand in for the current server data. A default|

### on()
Attach an event handler. `Client` is an `EventEmitter`.

|Parameter|Notes|
|---------|-----|
|name|The name of the event you want to handle|
|callback|The event handler callback|

Events are listed below. In all cases `this` in the events refers to the
`Client` itself.

#### relinked
Fired when the connection has auto reconnected and all data has been
refreshed.

#### error
Fired on any socket reported error.

#### _topic_
Custom events fired by `send`.

### send([client], topic, message)
Point-to-point messaging, allowing connected clients to exchange
messages through the server. You can do a lot of things with this, but
it was added as a mechanism to negoatiate WebRTC/ICE connectivity, which
is all about peer-to-peer offer answer pairs to set up connectivity.

This is a very simple way to send notifications / pokes / alerts from
one client to another.

With all three parameters, this is a send to a single client. With two
parameters, this is a send to all attached clients. Pointcast.
Broadcast.

|Parameter|Notes|
|---------|-----|
|client|A client identifier, you get your own identifier with `client`|
|topic|A topic string, listen for this with `Client.on`|
|message|Any JSON serializable object|

### close()
Close off the connection, this will end attempts to reconnect, and close
every `Link` started from this `Client`.

## Server
This is the main object you create on the server, `new` it.

|Parameter|Notes|
|---------|-----|
|options|An option hash|

|Option|Notes|
|------|-----|
|storageDirectory|Root directory for snapshots and journals, this is used to maintain state|

### hook()
On the server, you can _hook_ which is a system of data middleware. This
is similar to setting up routes on an HTTP server, and gives you the
chance to intercept:

* Reads, before they go back to a client
* Writes, before they are saved into Variable Sky

And, it is a great place for you to integrate in other systems including:

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

### prev
Get the previous value of of the data before this current hook sequence
started.

|Event|Notes
|-----|----|
|link|`prev` is the stored server, which will be the same as `val`|
|save|`prev` is the stored server, about to be replaced|
|remove|`prev` is the stored server, about to be removed|

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
The current value of the link, as replicated from the server. This will
not exist until data makes it back.

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
|callback| (error, snapshot) fired when the save has completed to the server|

### merge()
Merge additional properties to a linke. This **adds** to the existing
value, notifies the server, then replicates to all clients.

This notifies all child links and other cliens in the same way as
`Link.save()`.

|Parameter|Notes|
|---------|-----|
|value|Any JavaScript value, just a variable, no need to JSON it|
|callback| (error, snapshot) fired when the merge has completed to the server|

### saveDiff()
This is a smart save, intended to be used on arrays. It just sends a
diff, avoiding the need to ship an entire array back to the server.

Internally, the Angular bindings make use of this automatically.

|Parameter|Notes|
|---------|-----|
|oldValue|Any JavaScript value, just a variable, no need to JSON it|
|newValue|Any JavaScript value, just a variable, no need to JSON it|
|callback| (error, snapshot) fired when the save has completed to the server|

### remove()
Remove lets you _undefine_ a variable on the server. This is different
than `null`.

|Parameter|Notes|
|---------|-----|
|callback| (error) fired when the remove has completed to the server|

### autoRemove()
Mark a link as self-deleting when the connection is closed. This is a
very simple way to implement presence features by having a variable
lifetime tied to a client connection.

|Parameter|Notes|
|---------|-----|
|callback| (error) fired when the autoremove is registered on the server|

### concurrentEdit()
Enable concurrent editing by a text editing HTML element Simply call
this method, and your users will engage in real time concurrent editing
against the linked data.

You need to use this on a string property.

|Parameter|Notes|
|---------|-----|
|element|An editable DOM element|
|returns|A function, when called ends the editing|

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
Appoint a user/group as the owner. Sometimes you just need to let go,
this is how you do it.

|Parameter|Notes|
|---------|-----|
|id|A user or group to own the data|
