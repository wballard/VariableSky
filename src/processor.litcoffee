A command processor, this brings together multiple command implementations,
then dispatches commands to those implementations. Having this central
processor provides:

* A blackboard, which is the shared context for commands to 'store' state
* A place to journal commands, for later playback
* Command lookup, so we can have command implementations just be functions

Commands are really just middleware, but instead of a response, they get a
blackboard. The signature of an implementation is:

`fn(todo, blackboard, done)`

This is all node callback style `(error, result)` on done. Except there is no
result, so call `done()` or `done(error)`


    fs = require('fs')
    path = require('path')
    util = require('util')
    Blackboard = require('./blackboard')
    Journal = require('./journal')
    EventEmitter = require('events').EventEmitter


    class Processor
        constructor: (@options) ->
            options = @options = @options or {}
            options.commandDirectory = options.commandDirectory or path.join(__dirname, 'commands')
            options.journalDirectory = options.journalDirectory or path.join(__dirname, '..', '.journal')

Commands get to write to the `blackboard` however they see fit. Playing back
a set of commands in the same order against the same starting blackboard should
result in the same state. Should. Which is to say, you need to make commands
deterministic for this to work out.

            @blackboard = new Blackboard()


A list of all the commands 'todo'. This provides a place to queue up commands
in two interesting cases:

* Startup, not cool to run new commands until fully recovered
* Distributed, commands coming in from other processess replicas

            @todos = []

The processor, it loads up available commands from a directory, hashing
them by name without extension, using `require` to load them, so this expects
that each command module exposes exactly the function taht is the command
implementation.

            @commands = {}
            for file in fs.readdirSync(options.commandDirectory)
                name = path.basename(file, path.extname(file))
                @commands[name] = require path.join(options.commandDirectory, file)

And, a bit different implementation, this is event driven.

            @emitter = new EventEmitter()

The event for actual command execution. This is the 'internal' execution
event, that just performs the core execution logic.

            @emitter.on 'execute', (todo, handled, skipped) =>
                if @commands[todo.command]
                    @commands[todo.command](todo, @blackboard, handled)
                else
                    skipped()

Initially, just queue things up to give the journal time to recover.

            @emitter.on 'do', () =>
                @todos.push arguments

And commands are written to a journal, providing durability

            @journal = new Journal @options, =>

On startup, the journal recovers, and when it is full recovered, connect the
command handling 'do' directly to 'exec', no more buffering.

                @emitter.removeAllListeners 'do'
                @emitter.on 'do', (todo, handled, skipped) =>
                    @emitter.emit 'execute', todo, handled, skipped

Forward all queued events that were buffered up during recovery

                while @todos.length
                    todo = @todos.shift()
                    @emitter.emit 'execute', todo?[0], todo?[1], todo?[2]


The actual command execution function, callers will use this to get the
processor to do work for them. `todo` is the input, the two callbacks `handled`
and `skipped` called respectively if there was a command found for the `todo`.

        do: (todo, handled, skipped) =>
            if @commands[todo.command]?.DO_NOT_JOURNAL
                #just go for it
                @emitter.emit 'do', todo, handled, skipped
            else
                #journal, then execute
                @journal.record todo, (error) =>
                    if error
                        handled error
                    else
                        @emitter.emit 'do', todo, handled, skipped

    module.exports = Processor
