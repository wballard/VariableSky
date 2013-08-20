This is a browser specific shim version of the CommandProcessor. Temporary,
as browserify lacks v0.10.x style stream class shims. Bummer.

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
          todo.error =
            name: "NO_SUCH_COMMAND"
            message: command
          stream.emit 'data', todo
