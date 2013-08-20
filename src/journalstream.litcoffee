Read all commands from the journal, used to restore the blackboard state.

Recording to disk makes the command processing system durable, using the same
techniques as a database with write ahead logging.

    Readable = require('stream').Readable
    Writable = require('stream').Writable
    leveldown = require('leveldown')

    class Reader extends Readable
      constructor: (options) ->
        super objectMode: true
      _read: () ->
        @push(null)

    class Writer extends Writable
      constructor: (@options) ->
        super objectMode: true
      close: (done) ->
        @database.close done
      _write: (todo, encoding, next) ->
        outbound = (todo, next) =>
          key = String('0000000000000000'+@counter++).slice(-16)
          @database.put key, JSON.stringify(todo), next
        if not @database
          @database = leveldown(@options.journalDirectory)
          @on 'finish', =>
            @database.close =>
              @emit 'shutdown'
          @database.open (error) =>
            return next(error, todo) if error
            highmark = @database.iterator()
            highmark.next (error, key, value) =>
              return next(error, todo) if error
              @counter = key or 0
              highmark.end (error) =>
                return next(error, todo) if error
                outbound todo, next
        else if todo
          outbound todo, next
        else
          console.log 'closing'

    module.exports =
      Reader: Reader
      Writer: Writer


