Link to data on a `Blackboard` by `path`.

Links are asynchronous, dispatching a `link` command to fulfill themselves
with data via event.

This gives you a clone of the linked data, which is a simulation of sending
the data over the wire to a client as JSON. This is to keep behavior the
same on client as on server, in that you must `save`, `remove`, `set`, or call
an Array mutator.

    parsePath = require('./util.litcoffee').parsePath
    _ = require('lodash')

    class Link
        constructor: (@processor, path, dataCallback, @onClose) ->
            @path = parsePath(path)
            @count = 0
            @dataCallback = (error, value) =>
                @count += 1
                dataCallback.call(this, error, value) if dataCallback
            @save = (value, done) ->
                processor.do {command: 'save', path: @path, val: value}, (error, val) =>
                    if error
                        done(error) if done
                        @dataCallback error
                    else
                        cloner = _.cloneDeep(val)
                        done(undefined, cloner) if done
                        @dataCallback undefined, cloner
                this
            @remove = (done) ->
                processor.do {command: 'remove', path: @path}, (error, val) =>
                    if error
                        done(error) if done
                        @dataCallback error
                    else
                        done() if done
                        @dataCallback undefined, undefined
                this
            processor.do {command: 'link', path: @path}, (error, val) =>
                if error
                    @dataCallback error
                else
                    @dataCallback undefined, _.cloneDeep(val)

        fireCallback: (error, newVal) ->
            if not error
                @val = newVal
            @dataCallback error, @val

        close: ->
            @onClose()

    module.exports = Link
