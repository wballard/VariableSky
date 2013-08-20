A command processing streams turns *todo* into *done* by way of *commands*.

You set up a with `commandstream(commandMap, lookup, context)`, this returns a
stream. You write `todo` message to it, and the stream does them.

Todos are simply any object, this is an input message.

Commands are really just functions that do things. The signature of an
implementation is:

`command(todo, context, done)`

You call done when done. This is asynchronous middleware.

Commands are registered by `commandMap`, with a simple object, just

```
  name: command_function
  othername: command_function
```

Commands are looked up by a supplied function that identifies commands by name,
with a function that returns a string command name, matching into the
`commandMap`.

`lookup(todo)`

Commands can be skipped, this is most likely when you have a prior error
in stream and want to avoid processing. Return true to skip.

`skip(todo)`

Commands have shared state via a `context`. This is any object you like, and
lives as long as the stream.

    es = require('event-stream')
    _ = require('lodash')
    errors = require('./errors.litcoffee')

    module.exports = (commandMap, lookup, skip, context) ->
      stream = es.through (todo) ->
        command = commandMap[lookup(todo)]
        mustSkip = (skip or -> false)(todo)
        if mustSkip
          stream.emit 'data', todo
        else if command
          command todo, context, (error) ->
            if error
              todo.error = error
            stream.emit 'data', todo
        else
          lookup.error = errors.NO_SUCH_COMMAND
          stream.emit 'data', todo
