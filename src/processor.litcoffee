A command processor, this brings together multiple command implementations,
then dispatches commands to those implementations. Having this central
processor provides:

* A blackboard, which is the shared context for commands to 'store' state
* Command lookup, so we can have command implementations just be functions
* Hooks to intercept before and after commands, assuming that a todo has a `.path`

Commands are really just middleware, but instead of a response, they get a
blackboard. The signature of an implementation is:

`fn(todo, blackboard, done)`

This is all node callback style `(error, result)` on done. On success, pass
back the `todo` with `done(null, todo)`.

    fs = require('fs')
    path = require('path')
    util = require('util')
    errors = require('./errors.litcoffee')
    _ = require('lodash')
    assert = require('assert')
    Blackboard = require('./blackboard.litcoffee')
    Link = require('./link.litcoffee')
    Router = require('./router.litcoffee').ExactRouter
    EventEmitter = require('events').EventEmitter
    packPath = require('./util.litcoffee').packPath

Used in hooks to provide access to data.

    class HookContext
        constructor: (processor, todo, done) ->
            _.extend this, todo,
                prev: processor.blackboard.valueAt(todo.path)
                abort: (message) ->
                    throw errors.HOOK_ABORTED(message)

Build a new link, notice how we get at the process via the parameter
to construct, but don't even store it in `this`. Trying really hard to make
clients to through `Link`.

                link: (path, done) ->
                    new Link(processor, path, done)

    class Processor extends EventEmitter
        constructor: () ->
            @todos = []
            @counter = 0

Commands get to write to the `blackboard` however they see fit. Playing back
a set of commands in the same order against the same starting blackboard should
result in the same state. Should. Which is to say, you need to make commands
deterministic for this to work out.

            @blackboard = new Blackboard()

Uses `director` for hook routing for _each command_. Separate routing tables
for each coomand. Keeps it compact.

            @hooks = {}

The processor, it loads up available commands from a directory, hashing
them by name without extension, using `require` to load them, so this expects
that each command module exposes exactly the function taht is the command
implementation.

            @commands = {}
            @beforeHooks = new Router()
            @afterHooks = new Router()


Before hooks fire before the command has started.

        hookBefore: (command, path, hook) =>
            @beforeHooks.on command, path, hook

After hooks fire when the executed command has completed.

        hookAfter: (command, path, hook) =>
            @afterHooks.on command, path, hook

Direct execution, without any hooks -- useful for recovery.

        directExecute: (todo, done) =>
            command = @commands[todo.command]
            if command
                command todo, @blackboard, done
            else
                done(errors.NO_SUCH_COMMAND())

The actual command execution function, callers will use this to get the
processor to do work for them.

Commands are run, then journaled. This is to isolate the actual memory
modification from the hooks. Basically, imagine a hook that sends email. Then
imagine we were playing back input rather than results. Email firehose. Not cool.

Similar case with non-deterministic hooks, like setting a guid or timestamp.
Hooks only fire the first time, and are not played back / replicated.

        do: (todo, done) =>
            assert _.isObject(todo), _.isFunction(done), "todo and done must be an object and a function, respectively"
            todo.__id__ = todo.__id__ or "#{Date.now()}:#{@counter++}"

The execute event needs to figure if there is even a command registered,
otherwise this is skipped as unhandled.

            command = @commands[todo.command]
            if command

The start of the sequence. The request extends the todo, providing execution
context. Most important here is `val`, as before hooks get a chance to override
this content, which will then be passed along to the core. That's the main
thing going on, re-writing `val`.

                req = new HookContext(this, todo, done)
                @beforeHooks.dispatch todo.command, packPath(req.path), req, (error) =>
                    if error
                        if todo.__trace__
                            console.error 'before hook failed', error
                        done error, undefined, todo
                    else
                        todo.val = req.val

The core command execution, here is the writing to the blackboard. These are
internal commands, not user hooks, so they get to really store data.

                        @commands[todo.command] todo, @blackboard, (error, todo) =>
                            if error
                                done error, undefined, todo
                            else

And the final after phase, last chance to modify the `val` before it is
sent along to any clients.

                                @afterHooks.dispatch todo.command, packPath(req.path), req, (error) =>
                                    if error
                                        done error, undefined, todo
                                    else
                                        done undefined, req.val, todo

An event, let's us hook up a journal.

                                        @emit 'done', req.val, todo
            else
                done errors.NO_SUCH_COMMAND(), undefined, todo

Queue up todo items for later processing.

        enqueue: (todo, done) =>
            @todos.push {todo: todo, done: done}

Drain the queued items.

        drain: =>
            while @todos.length
                queued = @todos.shift()
                @do queued.todo, queued.done

    module.exports = Processor
