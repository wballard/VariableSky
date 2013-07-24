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

    class Link
        constructor: (processor, path, callback, onClose) ->
            @path = parsePath(path)
            @count = 0
            dataCallback = (error, value) =>
                @count += 1
                callback.call(this, error, value) if callback

Operations to the linked data are defined as closures over the processor.

            @save = (value, done) ->
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
