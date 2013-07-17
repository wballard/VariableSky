Link to data on a `Blackboard` by `path`.

Links are asynchronous, dispatching a `link` command to fulfill themselves
with data via event.

This gives you a clone of the linked data, which is a simulation of sending
the data over the wire to a client as JSON. This is to keep behavior the
same on client as on server, in that you must `save`, `remove`, `set`, or call
an Array mutator.

    parsePath = require('./util.litcoffee').parsePath
    _ = require('lodash')
    EventEmitter = require('events').EventEmitter

    class Link extends EventEmitter
        constructor: (@processor, path, @onClose) ->
            @path = parsePath(path)
            setTimeout =>
                processor.do {command: 'link', path: @path}, (error, val) =>
                    if error
                        @emit 'error', error
                    else
                        @emit 'link', _.cloneDeep(val)
            @save = (value) ->
                setTimeout =>
                    processor.do {command: 'save', path: @path, val: value}, (error, val) =>
                        if error
                            @emit 'error', error
                        else
                            @emit 'save', _.cloneDeep(val)
                this
            @remove = ->
                setTimeout =>
                    processor.do {command: 'remove', path: @path}, (error, val) =>
                        if error
                            @emit 'error', error
                        else
                            @emit 'remove'
                this

        close: ->
            @onClose()
            @removeAllListeners()

    module.exports = Link
