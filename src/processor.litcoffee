A command processor, this brings together multiple command implementations,
then dispatches commands to those implementations. Having this central
processor provides:

* A blackboard, which is the shared context for commands to 'store' state
* A place to journal commands, for later playback
* Command lookup, so we can have command implementations just be functions

Commands are really just middleware, but instead of a response, they get a
blackboard. The signature of an implementation is:

`fn(todo, blackboard, done)`

This is all node callback style `(error, result)` on done. On success, pass
back the `todo` with `done(null, todo)`.

    fs = require('fs')
    path = require('path')
    util = require('util')
    errors = require('./errors')
    _ = require('lodash')
    Blackboard = require('./blackboard')
    Link = require('./link')
    Journal = require('./journal')
    EventEmitter = require('events').EventEmitter

    director = require('director')

Used in hooks to provide access to data.

    class HookContext
        constructor: (processor, todo, done, next) ->
            _.extend this, todo,
                method: todo.command
                headers: {}
                url: "/#{todo.href.join('/')}"
                prev: processor.blackboard.valueAt(todo.href)
                abort: ->
                    if arguments.length
                        done this, arguments
                    else
                        done errors.HOOK_ABORTED()
                next: next

Build a new link, notice how we get at the process via the parameter
to construct, but don't even store it in `this`. Trying really hard to make
clients to through `Link`.

                link: (href) ->
                    new Link(processor, href)

    class Processor
        constructor: (@options) ->
            @counter = 0
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

Uses `director` for hook routing for _each command_. Separate routing tables
for each coomand. Keeps it compact.

            @hooks = {}

The processor, it loads up available commands from a directory, hashing
them by name without extension, using `require` to load them, so this expects
that each command module exposes exactly the function taht is the command
implementation.

            @commands = {}
            for file in fs.readdirSync(options.commandDirectory)
                name = path.basename(file, path.extname(file))
                @commands[name] = require path.join(options.commandDirectory, file)
            @beforeHooks = new director.http.Router().configure
                async: true
                notfound: ->
                    this.req.next()
            @beforeHooks.extend _.keys(@commands)
            @afterHooks = new director.http.Router().configure
                async: true
                notfound: ->
                    this.req.next()
            @afterHooks.extend _.keys(@commands)

And, a bit different implementation, this is event driven.

            @emitter = new EventEmitter()

The event handling for actual command execution. This is three events

* `executeBefore`
* `executeCore`
* `executeAfter`

This event chain provides a place to hook asynchronously.

The start of the sequence. The request extends the todo, providing execution
context. Most important here is `val`, as before hooks get a chance to override
this content, which will then be passed along to the core. That's the main
thing going on, re-writing `val`.

            @emitter.on 'executeBefore', (todo, done) =>
                req = new HookContext this, todo, done, (error) =>
                    if error
                        done(error)
                    else
                        todo.val = req.val
                        @emitter.emit 'executeCore', todo, done
                res = {}
                @beforeHooks.dispatch req, res, req.next

The core command execution, here is the writing to the blackboard. These are
internal commands, not user hooks, so they get to really store data.

            @emitter.on 'executeCore', (todo, done) =>
                @commands[todo.command] todo, @blackboard, (error, todo) =>
                    if error
                        done(error)
                    else
                        @emitter.emit 'executeAfter', todo, done

And the final after phase, last chance to modify the `val` before it is
sent along to any clients.

            @emitter.on 'executeAfter', (todo, done) =>
                req = new HookContext this, todo, done, (error) =>
                    if error
                        done(error)
                    else
                        done(null, req.val)
                res = {}
                @afterHooks.dispatch req, res, req.next

The execute event needs to figure if there is even a command registered,
otherwise this is skipped as unhandled.

            @emitter.on 'execute', (todo, done) =>
                if @commands[todo.command]
                    @emitter.emit 'executeBefore', todo, done
                else
                    done(errors.NO_SUCH_COMMAND())

Initially, just queue things up to give the journal time to recover.

            @emitter.on 'do', () =>
                @todos.push arguments

And commands are written to a journal, providing durability. The journal is
given a function to recover each command.

            recover = (todo, next) =>
                todo.__recovering__ = true
                @commands[todo.command] todo, @blackboard, (error, todo) =>
                    if error
                        util.error 'recovery error', util.inspect(error)
                    next()

            @journal = new Journal @options, recover, =>

On startup, the journal recovers, and when it is full recovered, connect the
command handling 'do' directly to 'exec', no more buffering.

                @emitter.removeAllListeners 'do'
                @emitter.on 'do', (todo, done) =>
                    @emitter.emit 'execute', todo, done

Forward all queued events that were buffered up during recovery

                while @todos.length
                    todo = @todos.shift()
                    @emitter.emit 'execute', todo?[0], todo?[1]

Clean shutdown.

        shutdown: (callback) ->
            @journal.shutdown callback

Before hooks fire before the command has started.

        hookBefore: (command, href, hook) ->
            @beforeHooks[command] href, (next) ->
                try
                    hook this.req, next
                catch error
                    next error

After hooks fire when the executed command has completed.

        hookAfter: (command, href, hook) ->
            @afterHooks[command] href, (next) ->
                try
                    #params and next
                    params = _.toArray(arguments)
                    #but we need to splice in the context
                    params.splice(-1, 0, this.req)
                    hook.apply this, params
                catch error
                    next error

The actual command execution function, callers will use this to get the
processor to do work for them.

Commands are run, then journaled. This is to isolate the actual memory
modification from the hooks. Basically, imagine a hook that sends email. Then
imagine we were playing back input rather than results. Email firehose. Not cool.

Similar case with non-deterministic hooks, like setting a guid or timestamp.
Hooks only fire the first time, and are not played back / replicated.

        do: (todo, done) =>
            todo.__id__ = "#{Date.now()}:#{@counter++}"
            @emitter.emit 'do', todo, (error, val) =>
                if error
                    done error
                else
                    if @commands[todo.command]?.DO_NOT_JOURNAL
                        done null, val
                    else
                        @journal.record todo, (error) =>
                            if error
                                done error
                            else
                                done null, val

    module.exports = Processor
