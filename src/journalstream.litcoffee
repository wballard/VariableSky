Read all commands from the journal, used to restore the blackboard state.

Recording to disk makes the command processing system durable, using the same
techniques as a database with write ahead logging.

    Readable = require('stream').Readable
    Writable = require('stream').Writable
    leveldown = require('leveldown')

    class Reader extends Readable
      constructor: (@options) ->
        super objectMode: true
      _read: () ->
        if not @database
          @database = leveldown(@options.journalDirectory)
          @on 'end', =>
            @database.close =>
              @emit 'shutdown'
          @database.open (error) =>
            return next(error, todo) if error
            todos = @database.iterator()
            each = (error, key, value) =>
              if error
                @emit 'error', error
              else if value
                @push(JSON.parse(value))
                todos.next each
              else
                @push({})
                @push(null)
            todos.next each

    class Writer extends Writable
      constructor: (@options) ->
        super objectMode: true
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
            highmark = @database.iterator(reverse: true)
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


