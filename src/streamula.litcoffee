**Streamula**, puts its fangs into your program and makes everything flow using
streams rather than the pyramid of doom.

More to the point, Streamula uses new and exciting v0.10.x streams to allow
simple functional streaming programming. Use these exciting stream types, pipe
them together and go wild. Wild I say!

    stream = require('stream')

## Notes
All of these streams are classes, but for the object disinclined, you can go
at them with a function too. Save the baby `new`s.

So, for stream `new streamula.Map()` you can also say `streamula.map()`. I'm
just that considerate.

## Map(mapFunction)
Map every incoming object to an output object. This is smart enough that when
it gets a `null` it knows the stream is over and it doesn't bother you.

### mapFunction(value)
This handles the synchronous case, whatever you return will be sent along. If
you come back with a `null`, you are telling everyone downstream that it's all
over.

    class Map extends stream.Transform
      constructor: (@mapFunction) ->
        super objectMode: true
      _transform: (object, encoding, callback) ->
        if object
          try
            @push(@mapFunction(object))
            callback()
          catch err
            callback(err)
        else
          console.log 'nomap'
          @push(null)
          callback()

## CommandProcessor(options)
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

    class CommandProcessor extends stream.Transform
      constructor: (@options) ->
        super objectMode: true
        @options.map = @options.map or {}
        @options.lookup = @options.lookup or ->
        @options.skip = @options.skip or -> false
        @options.context = @options.context or {}
      _transform: (todo, encoding, callback) ->
        push = (todo) =>
          @push(todo)
          callback()
        command = @options.map[@options.lookup(todo)]
        mustSkip = @options.skip(todo)
        if mustSkip
          push(todo)
        else if command
          if command.length is 3
            command todo, @options.context, (error) =>
              if error
                todo.error = error
              push(todo)
          else
            command todo, @options.context
            push(todo)
        else
          todo.error =
            name: "NO_SUCH_COMMAND"
            message: command
          push(todo)


    module.exports =
      Map: Map
      map: (mapFunction) -> new Map(mapFunction)
      CommandProcessor: CommandProcessor
      commandprocessor: (options) -> new CommandProcessor(options)
