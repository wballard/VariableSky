A journal, which records a series of items to disk for later playback. This uses an
append only database supporting range key iteration to allow for iteration
from a checkpoint/snapshot.

Recording to disk makes the command processing system durable, using the same
techniques as a database with write ahead logging.

    class Journal
        constructor: (@options) ->

        recover: (callback) ->
            callback()

        record: (todo, callback) ->
            callback()

    module.exports = Journal
