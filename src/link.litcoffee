Link to data on a `Blackboard` by `path`.

Links are asynchronous, dispatching a `link` command to fulfill themselves
with data via event.

This gives you a clone of the linked data, which is a simulation of sending
the data over the wire to a client as JSON. This is to keep behavior the
same on client as on server, in that you must `save`, `remove`, `set`, or call
an Array mutator.

    parsePath = require('./util.litcoffee').parsePath
    errors = require('./errors.litcoffee')
    _ = require('lodash')
    adiff = require('adiff')
    EventEmitter = require('events').EventEmitter

    class Link extends EventEmitter
        constructor: (processor, blackboard, path, callback, onClose) ->
            @path = parsePath(path)
            @count = 0
            diff = adiff.diff
            dataCallback = (error, value, todo) =>
                @val = value
                @count += 1
                callback.call(this, error, value, todo) if callback
                @emit 'data', value

Operations to the linked data are defined as closures over the processor, so
they are tucked in here...

Sometimes you need to redefine equals. Specifically for angular, to ignore $$.

            @equalIs = (fn) ->
                diff = adiff(equal: fn).diff
                this

Save does what you would think, replaces and entire value.

            @save = (value, done) ->

The array case. As far as I can think of it there are two cases:

* you save the same array instance as is in the client, having modified it
* you make a new array, clone, etc, modify, and replace

In the instance where you modify the array, the local in client image of the array
is already up to date, which means no need for a local modify, and only a need
to send the diff along to the server.

In the other case, it is just a new object and save it.

                todo = {command: 'save', path: @path, val: value}
                processor.do todo, (error, val, todo) =>
                    if error
                        done(error, undefined, todo) if done
                        dataCallback error, undefined, todo
                    else
                        done(undefined, val, todo) if done
                        dataCallback undefined, val, todo
                this

Save diff tries to just send updates, this is currently only useful on arrays.
You feed it an old and new value, so in practice this is called from the angular
bindings as there is already an 'old' copy in memory, no sense in making yet
another copy...

            @saveDiff = (newValue, oldValue, done) ->
                if _.isArray(oldValue) and _.isArray(newValue)
                    todo =
                        command: 'save'
                        path: @path
                        diff: diff(oldValue, newValue)
                    processor.do todo, (error, val, todo) =>
                        if error
                            done(error) if done
                            dataCallback error, undefined, todo
                        else
                            done(undefined, val) if done
                            dataCallback undefined, val, todo
                else
                    @save newValue, done

Totally blows away a value, making it `undefined`.

            @remove = (done) ->
                processor.do {command: 'remove', path: @path}, (error, val, todo) =>
                    if error
                        done(error) if done
                        dataCallback error, undefined, todo
                    else
                        delete @val
                        done() if done
                        dataCallback undefined, undefined, todo
                this

Mark a variable as self deleting on disconnect. Useful to implement presence.

            @autoRemove = (done) ->
                processor.do {command: 'autoremove', path: @path}, (error, value, todo) =>
                    if error
                        done(error) if done
                    else
                        done() if done
                this

Force fire the data callback, used when you get a message from another client.

            @fireCallback = (error, newVal, todo) ->
                if not error
                    @val = newVal
                dataCallback error, newVal, todo

Closing, with a callback. Clients closing close all their allocated links this way.

            @close = ->
                onClose() if onClose

This actually starts off the link, by processing a command to link.

            processor.do {command: 'link', path: @path}, (error, val, todo) =>
                if error
                    dataCallback error, undefined, todo
                else
                    dataCallback undefined, val, todo

    module.exports = Link
