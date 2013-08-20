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
          diff = adiff.diff

Sometimes you need to redefine equals. Specifically for angular, to ignore $$.

          @equalIs = (fn) ->
            diff = adiff(equal: fn).diff
            this

          @processor = processor
          @path = parsePath(path)
          @count = 0
          @dataCallback = (error, value, todo) =>
            @val = value
            @count += 1
            callback.call(this, error, value, todo) if callback
            @emit 'data', value
          @onClose = onClose

This actually starts off the link, by processing a command to link.

          processor.write
            command: 'link'
            path: @path

Save does what you would think, replaces an entire value.

        save: (value, done) ->
          @processor.write
            command: 'save'
            path: @path
            val: value
            __done__: done
          this

Save diff tries to just send updates, this is currently only useful on arrays.
You feed it an old and new value, so in practice this is called from the angular
bindings as there is already an 'old' copy in memory, no sense in making yet
another copy...

        saveDiff: (newValue, oldValue, done) ->
          if _.isArray(oldValue) and _.isArray(newValue)
            @processor.write
              command: 'save'
              path: @path
              diff: diff(oldValue, newValue)
              __done__: done
          else
            @save newValue, done
          this

Totally blows away a value, making it `undefined`.

        remove: (done) ->
          @processor.write
            command: 'remove'
            path: @path
            __done__: done
          this

Mark a variable as self deleting on disconnect. Useful to implement presence.

        autoRemove: (done) ->
          @processor.write
            command: 'autoremove'
            path: @path
            __do_not_dispatch__: true
            __done__: done
          this

Closing, with a callback. Clients closing close all their allocated links this way.

        close: (done) ->
          @onClose(this)
          @processor.write
            command: 'closelink'
            path: @path
            __do_not_dispatch__: true
            __done__: done
          this

    module.exports = Link
