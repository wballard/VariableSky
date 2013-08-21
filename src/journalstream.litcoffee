Read all commands from the journal, used to restore the blackboard state.

Recording to disk makes the command processing system durable, using the same
techniques as a database with write ahead logging.

    Readable = require('stream').Readable
    Writable = require('stream').Writable
    leveldown = require('leveldown')

## reader(options)

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

## writer(options)

Stream will write out records to the journal. Big thing to pay attention to is
to not open this more than once, file locks and all that.

By going into a journal stream, if you write before you return, you are just
like a grown up database for durability. Cool. If you go all asynch, you are
more optimistic, which is great when you have an online replica system. Or have
data that is better to be fast than perfect, which in my opinion is always.


### options
|Name|Description|
|-|-|
|journalDirectory|Disk location for the journal. Mandatory|

    writer = (options) ->
      ret = new Writable(objectMode: true)
      buffer = new Readable(objectMode: true)
      buffer._read = ->
      started = false
      counter = 0
      database = null
      ret.on 'finish', ->
        database.close ->
          ret.emit 'shutdown'
      ret._write = (todo, encoding, next) ->
        buffer.push
          data: todo
          next: next
        start() if not started

Implementation wise, this is a bit tricky. You write to this guy, but internally
it has a read stream that buffers up writes until the database is open. Yeah
asynchronicity. But, piping makes this pretty easy. Well, sorta easy, this is
piggybacking on the `next` callback to avoid piling up.

      start = ->
        started = true
        database = leveldown(options.journalDirectory)
        database.open (error) ->
          return ret.emit('error', error) if error
          highmark = database.iterator(reverse: true)
          highmark.next (error, key, value) ->
            return ret.emit('error', error) if error
            counter = parseInt(key or '0')
            highmark.end (error) ->
              return ret.emit('error', error) if error
              theRealDeal = new Writable(objectMode: true)
              theRealDeal._write = (todo, encoding, next) ->
                key = String('0000000000000000'+counter++).slice(-16)
                database.put key, JSON.stringify(todo.data), ->
                  next()
                  todo.next()
              buffer.pipe(theRealDeal)
      ret

    module.exports =
      reader: reader
      writer: writer


