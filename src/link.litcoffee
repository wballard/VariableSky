Link to data on a `Blackboard` by `href`.

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
        constructor: (@processor, href) ->
            @href = parsePath(href)
            setTimeout =>
                processor.do {command: 'link', href: @href}, (error, val) =>
                    if error
                        @emit 'error', error
                    else
                        @emit 'link', _.cloneDeep(val)
            @save = (value) ->
                setTimeout =>
                    processor.do {command: 'save', href: @href, val: value}, (error, val) =>
                        if error
                            @emit 'error', error
                        else
                            @emit 'save', _.cloneDeep(val)
                this
            @remove = ->
                setTimeout =>
                    processor.do {command: 'remove', href: @href}, (error, val) =>
                        if error
                            @emit 'error', error
                        else
                            @emit 'remove'
                this

    module.exports = Link
