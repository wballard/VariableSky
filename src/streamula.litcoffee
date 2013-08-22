**Streamula**, puts its fangs into your program and makes everything flow using
streams rather than the pyramid of doom.

More to the point, Streamula uses new and exciting v0.10.x streams to allow
simple functional streaming programming. Use these exciting stream types, pipe
them together and go wild. Wild I say!

    through = require('through')
    eyes = require('eyes').inspector({ stream: null })

Adaptive object dumper. Inside the browser, the eyes escape codes are no fun.

    inspect =  (thing) ->
      if window?
        thing
      else
        eyes(thing)

## map(mapFunction)
Map every incoming object to an output object. This is smart enough that when
it gets a `null` it knows the stream is over and it doesn't bother you.

### mapFunction(value)
This handles the synchronous case, whatever you return will be sent along. If
you come back with a `null`, you are telling everyone downstream that it's all
over.

    map = (mapFunction) ->
      ret = through (object) ->
        try
          ret.queue(mapFunction(object))
        catch err
          ret.emit('error', err)

## commandprocessor(options)
A command processing streams turns *todo* into *done* by way of *commands*. This
combines the featuers of a *Command Processor* and a *Command Queue* with a
*Blackboard* allowing commands to collaborate, as well as to save state.

*Todos* are any object coming in on the stream.

*Commands* are really just functions that do things. Both synchronous and
asynchronous modes are supported:

* `fn(todo, context, callback)`
* `fn(todo, context)`

### options
|Name|Description|
|----|-----------|
|map|This is an object that maps `name` -> `command`|
|lookup|This is a `fn(todo)` that returns a `name`|
|skip|This is a `fn(todo)` that if true, skips processing|
|context|This is a shared object _blackboard_ where commands can record state|

    commandprocessor = (options) ->
      options.map = options.map or {}
      options.lookup = options.lookup or ->
      options.skip = options.skip or -> false
      options.context = options.context or {}
      ret = through (object) ->
        command = options.map[options.lookup(object)]
        mustSkip = options.skip(object)
        if mustSkip
          ret.queue(object)
        else if command
          if command.length is 3
            command object, options.context, (error) =>
              if error
                object.error = error
              ret.queue(object)
          else
            command object, options.context
            ret.queue(object)
        else
          object.error =
            name: "NO_SUCH_COMMAND"
            message: command
          ret.queue(object)

## decode()
Take a chunk off the stream and decode it into an object.

    decode = ->
      ret = through (object) ->
        ret.queue(JSON.parse(object))

## encode()
Take an object off the stream and encode it into a string.

    encode = ->
      ret = through (object) ->
        ret.queue(JSON.stringify(object))

## echo()
Everyone's favorite do-nothing stream. It is however a nice thing to `pause()`.

    echo = through

## tap(prefix, guard)
Wiretap a stream, printing out the inner goodness as each message goes by.

|Argument|Description|
|----|-----------|
|prefix|String that will go before each log message|
|guard|Function(loggedObject), if truthy, your object will be logged|

    tap = (prefix, guard) ->
      guard = guard or -> true
      ret = through (object) ->
        console.log(prefix, inspect(object)) if guard(object)
        ret.queue(object)

## discard()
This stream really does nothing. I mean it.

    discard = ->
      through ->

## pipeline(stream...)
Feed a comma separated multiple argument set of streams in, get a fully piped
stream out.

    pipeline = (stream...) ->
      root = stream.shift()
      stream.reduce(((l, r) -> l.pipe(r)), root)
      root


    module.exports =
      map: map
      commandprocessor: commandprocessor
      decode: decode
      encode: encode
      echo: echo
      tap: tap
      discard: discard
      pipeline: pipeline
