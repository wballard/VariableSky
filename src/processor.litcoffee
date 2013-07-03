A command processor, this brings together multiple command implementations,
then dispatches commands to those implementations. Having this central
processor provides:

* A place to log commands, for later playback
* Command lookup, so we can have command implementations just be functions

Commands are really just middleware, but instead of a response, they get a
blackboard. The signature of an implementation is:
`fn(todo, blackboard, done)`
This is all node callback style `(error, result)` on done. Except there is no
result, so call `done()` or `done(error)`

Commands get to write to the `blackboard` however they see fit.

    fs = require('fs')
    path = require('path')
    util = require('util')

The processor, it loads up available commands from a directory, hashing
them by name without extension, using `require` to load them, so this expects
that each command module exposes exactly the function taht is the command
implementation.

    class Processor
        constructor: (@blackboard, commandDirectory) ->
            @commands = {}
            for file in fs.readdirSync(commandDirectory)
                name = path.basename(file, path.extname(file))
                @commands[name] = require path.join(commandDirectory, file)

Bind a context for a single request, this is a starting point that is separate
from subsequent commands, and mainly serves to get the blackboard in scope.

        begin: ->
            blackboard = @blackboard
            commands = @commands
            (todo, handled, skipped) ->
                if commands[todo.command]
                    commands[todo.command](todo, blackboard, handled)
                else
                    skipped()

    module.exports = Processor
