A journal, which records a series of items to disk for later playback. This uses an
append only database supporting range key iteration to allow for iteration
from a checkpoint/snapshot.

Recording to disk makes the command processing system durable, using the same
techniques as a database with write ahead logging.

    leveldown = require('leveldown')

    class Journal
        constructor: (@options, callback) ->
            @database = leveldown(@options.journalDirectory)
            @database.open =>
                toPlayback = @database.iterator()
                each = (error, key, value) ->
                    if not error and not key and not value
                        toPlayback.end callback
                    else
                        toPlayback.next each
                toPlayback.next each



        record: (todo, callback) ->
            #date based key string, these will sort in order
            key = String('00000'+Date.now()).slice(-16)
            @database.put key, JSON.stringify(todo), callback

    module.exports = Journal
