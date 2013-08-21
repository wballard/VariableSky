**Streamula**, puts its fangs into your program and makes everything flow using
streams rather than the pyramid of doom.

More to the point, Streamula uses new and exciting v0.10.x streams to allow
simple functional streaming programming. Use these exciting stream types, pipe
them together and go wild. Wild I say!

    through = require('through')

## map(mapFunction)
Map every incoming object to an output object. This is smart enough that when
it gets a `null` it knows the stream is over and it doesn't bother you.

### mapFunction(value)
This handles the synchronous case, whatever you return will be sent along. If
you come back with a `null`, you are telling everyone downstream that it's all
over.

    map = (mapFunction) ->
      through (object) ->
        try
          @queue(mapFunction(object))
        catch err
          @emit('error', err)

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
      through (todo, encoding, callback) ->
        command = options.map[options.lookup(todo)]
        mustSkip = options.skip(todo)
        if mustSkip
          @queue(todo)
        else if command
          if command.length is 3
            command todo, options.context, (error) =>
              if error
                todo.error = error
              @queue(todo)
          else
            command todo, options.context
            @queue(todo)
        else
          todo.error =
            name: "NO_SUCH_COMMAND"
            message: command
          @queue(todo)

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
      pipeline: pipeline
