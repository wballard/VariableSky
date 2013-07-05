A journal, which records a series of items to disk for later playback. This uses an
append only database supporting range key iteration to allow for iteration
from a checkpoint/snapshot.

Recording to disk makes the command processing system durable, using the same
techniques as a database with write ahead logging.

    leveldown = require('leveldown')

    class Journal
        constructor: (@options, playback, callback) ->
            @database = leveldown(@options.journalDirectory)
            @database.open =>
                toPlayback = @database.iterator()
                each = (error, key, value) ->
                    if not error and not key and not value
                        toPlayback.end callback
                    else
                        playback JSON.parse(value), ->
                            toPlayback.next each
                #start the pump
                toPlayback.next each

Clean shutdown.

        shutdown: (callback) ->
            @database.close callback

Record a command in the journal for later playback.

        record: (todo, callback) ->
            #date based key string, these will sort in order
            key = String('00000'+Date.now()).slice(-16)
            @database.put key, JSON.stringify(todo), callback

Throw away all journaled memory.

        reset: ->


    module.exports = Journal
