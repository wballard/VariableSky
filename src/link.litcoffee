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
        constructor: (@processor, path, @dataCallback, @onClose) ->
            @path = parsePath(path)
            processor.do {command: 'link', path: @path}, (error, val) =>
                if error
                    @dataCallback error
                else
                    console.log 'linko is his nameo'
                    @dataCallback undefined, _.cloneDeep(val)
            @save = (value) ->
                processor.do {command: 'save', path: @path, val: value}, (error, val) =>
                    if error
                        @dataCallback error
                    else
                        @dataCallback undefined, _.cloneDeep(val)
                this
            @remove = ->
                processor.do {command: 'remove', path: @path}, (error, val) =>
                    if error
                        @dataCallback error
                    else
                        @dataCallback undefined, undefined
                this

        close: ->
            @onClose()
            @removeAllListeners()

    module.exports = Link
