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

    class Link
        constructor: (processor, blackboard, path, callback, onClose) ->
            @path = parsePath(path)
            @count = 0
            priorArray = []
            dataCallback = (error, value) =>
                @count += 1
                priorArray = _.clone(value) if _.isArray(value)
                callback.call(this, error, value) if callback

Operations to the linked data are defined as closures over the processor, so
they are tucked in here...

Save does what you would think, but is smart enough to send only the diff for
an array.

            @save = (value, done) ->

The array case. As far as I can think of it there are two cases:

* you save the same array instance as is in the client, having modified it
* you make a new array, clone, etc, modify, and replace

In the instance where you modify the array, the local in client image of the array
is already up to date, which means no need for a local modify, and only a need
to send the diff along to the server.

In the other case, it is just a new object and save it.

                if blackboard.valueAt(path) is value and
                    _.isArray(value) and _.isArray(priorArray)
                        console.log 'diff', adiff.diff(priorArray, value)
                processor.do {command: 'save', path: @path, val: value}, (error, val) =>
                    if error
                        done(error) if done
                        dataCallback error
                    else
                        done(undefined, val) if done
                        dataCallback undefined, val
                this

            @remove = (done) ->
                processor.do {command: 'remove', path: @path}, (error, val) =>
                    if error
                        done(error) if done
                        dataCallback error
                    else
                        done() if done
                        dataCallback undefined, undefined
                this

            @push = (things...) ->
                #Variable numbers of arguments, but may have a callback.
                if _.isFunction(_.last(things))
                    done = _.last(things)
                    things = _.initial(things)
                else
                    done = ->
                processor.do {command: 'splice', path: @path, elements: things}, (error, val) =>
                    if error
                        done(error)
                        dataCallback error
                    else
                        done(undefined, val)
                        dataCallback undefined, val
                this

Force fire the data callback, used when you get a message from another client.

            @fireCallback = (error, newVal) ->
                if not error
                    @val = newVal
                dataCallback error, @val

            @close = ->
                onClose() if onClose

This actually starts off the link, by processing a command to link.

            processor.do {command: 'link', path: @path}, (error, val) =>
                if error
                    dataCallback error
                else
                    dataCallback undefined, val

    module.exports = Link
