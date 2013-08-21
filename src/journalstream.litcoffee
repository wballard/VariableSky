Read all commands from the journal, used to restore the blackboard state.

Recording to disk makes the command processing system durable, using the same
techniques as a database with write ahead logging.

    Readable = require('stream').Readable
    Writable = require('stream').Writable
    leveldown = require('leveldown')

# reader(options)

Stream will read all the records out of the journal and send them along. This
is the _playback_ sequence. You'll want to read all these back, do them, and
then start the actual server processing.

### options
|Name|Description|
|-|-|
|journalDirectory|Disk location for the journal. Mandatory|

    reader = (options) ->
      ret = new Readable(objectMode: true)
      ret.on 'end', ->
        database.close ->
          ret.emit 'shutdown'
      database = leveldown(options.journalDirectory)
      todos = null
      ret._read = ->
        each = (error, key, value) =>
          if error
            ret.emit('error', error)
          else if value
            ret.push(JSON.parse(value))
          else
            ret.push(null)
        if not todos
          database.open (error) ->
            return ret.emit('error', error) if error
            todos = database.iterator()
            todos.next each
        else
          todos.next each
      ret

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
      reader: reader
      Writer: Writer


