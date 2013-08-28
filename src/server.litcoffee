
    _ = require('lodash')
    pathjoin = require('path').join
    errors = require('./errors')
    Blackboard = require('./blackboard')
    Link = require('./link.litcoffee')
    wrench = require('wrench')
    browserify = require('browserify')
    parsePath = require('./util').parsePath
    packPath = require('./util').packPath
    connect = require('connect')
    EventEmitter = require('events').EventEmitter
    WebSocketServer = require('ws').Server
    inspect = require('./util.litcoffee').inspect
    hookstream = require('./hookstream.litcoffee')
    journalstream = require('./journalstream.litcoffee')
    websocket = require('websocket-stream')
    streamula = require('./streamula.litcoffee')

## Server
This is the main server object. This is a class to  hook to [connect] or
[express], I'm not all the way sure why you would want to, but you can make
multiple of these in a process and have separate sockets or rest url mount
points to them. I'd make some claim abut this being more testable, but I'd be
lying :)

    class Server extends EventEmitter
        constructor: (@options) ->
            @options = @options or {}
            @options.storageDirectory = @options.storageDirectory or pathjoin(process.cwd(), '.server')
            @options.journalDirectory = @options.journalDirectory or pathjoin(@options.storageDirectory, '.journal')
            @options.journal = if @options.journal? then @options.journal else true
            wrench.mkdirSyncRecursive(@options.storageDirectory)
            wrench.mkdirSyncRecursive(@options.journalDirectory)
            @blackboard = new Blackboard()

Track connections, and force close if we have a duplicate connection come in.

            @connections = connections = {}

Buffer messages out to clients, this allows you to get messages that are
waiting for you when you connect.

            messages = {}

This is the main command processor, separate here becuase it will be used in
journal playback without hooks as well as in the main workstream.

            commands = =>
              streamula.commandprocessor(
                map:
                  link: require('./commands/server/link')
                  save: require('./commands/server/save')
                  merge: require('./commands/server/merge')
                  remove: require('./commands/server/remove')
                  message: (todo) ->
                    buffer = (messages[todo.__to__] = messages[todo.__to__] or [])
                    if connection = connections[todo.__to__]
                      connection.write(todo)
                    else
                      buffer.push(todo)
                  hello: (todo) ->
                    buffer = (messages[todo.__client__] = messages[todo.__client__] or [])
                lookup: (m) -> m.command
                skip: (m) -> m.error
                context: @blackboard
              )

This is the main workstream, it does all the processing for the server.

            @workstream = streamula.pipeline(
              streamula.tap('Server Start', => @trace),
              gate = streamula.echo(),

Enhance the todo turning it into a context for the rest of the processing stream.

              contextify = streamula.act( (todo) =>
                if todo.path
                  _.extend(todo,
                    prev: @blackboard.valueAt(todo.path)
                    abort: (message) ->
                      throw errors.HOOK_ABORTED(message)
                  )
              ),

And here is where the real processing happens, hooks wrapping commands.

              @beforeHooks = hookstream((todo) -> "#{todo.command}:#{packPath(todo.path)}"),
              commands(),
              @afterHooks = hookstream((todo) -> "#{todo.command}:#{packPath(todo.path)}"),

Commands are written to a journal, providing durability and recovery.

              streamula.map( (todo) =>
                @emit 'done', todo
                todo
              ),
              streamula.tap('Server Done', => @trace),
              @journalstream = journalstream.writer(@options)
            )
            @workstream.on 'error', (error, todo) =>
              console.log 'horror', error
              if todo
                todo.error = error
                @emit 'error', todo
              else
                @emit 'error', error

Starting up, the command processing is paused at the gate, the journal is
played back to restore state, and then the gate is released.

            if not @options.journal
              #no action here
            else
              gate.pause()
              journalstream.reader(@options)
                .on('shutdown', gate.resume)
                .pipe(
                  commands()
                )

Clean server shutdown.

        shutdown: (done) =>
          @sock.close() if @sock
          @workstream.end()
          @journalstream.once 'shutdown', done

Hook support forwards to the correct streams, supports chaining.

        hook: (event, datapath, callback) ->
          switch event
            when 'link'
              @afterHooks.hook "#{event}:#{packPath(datapath)}", callback
            else
              @beforeHooks.hook "#{event}:#{packPath(datapath)}", callback
          this

This is a web socket listen, attached to a connect application
at a given mount point url with the default `/variablesky`.

        listen: (app, server, url) =>
          if not app.use
            throw errors.NOT_AN_APP()
          if @sock
            throw errors.ALREADY_LISTENING()

          url = url or '/variablesky'

If this looks like connect or express, install a client library handler and
and self check sample page. Detect connect/express with the presence of `use`.

          if app.use
            client = "#{pathjoin(url)}.client"
            app.use pathjoin(client, 'test'),
              connect.static(pathjoin(__dirname, '../test/client'))
            app.use client,  (req, res, next) ->
              res.setHeader('Content-Type', 'text/javascript')
              bundle = browserify()
                .transform(require('coffeeify'))
                .add(pathjoin(__dirname, 'client.litcoffee'))
                .bundle()
              bundle.pipe(res)
              bundle.on 'error', (error) ->
                res.statusCode = 500
                res.end("#{error}")
              bundle.on 'end', ->
                res.statusCode = 404
                res.end()

And, install the socket processing, this hands off to a `Connection` which is
a per client/connection abstraction.

            @sock = new WebSocketServer({server: server, path: url})
            @sock.on 'connection', (conn) =>
                new Connection(conn, this)

        traceOn: ->
          @trace = true
          this

A single server side connection instance, isolates the state of each client
from one another on the server.

    class Connection
      constructor: (conn, server) ->
        connection = @

When the server says it has journaled something, we need to route it to clients
that have a link to this path or a prefix of it so parent data knows about
child data changes.

        links = {}
        server.on 'done', routeDone = (todo) ->
          donepath = packPath(todo.path)
          for link in _.keys(links)
            if donepath.indexOf(link) is 0
              outbound.write todo
              return #only write it once, the client can multidispatch to links
        server.on 'error', routeDone

Streaming web sockets are go.

        socketstream = websocket(conn)

AutoRemove variables are tracked here by path.

        autoremove = {}

The outbound event stream, send messages along to a connected client.

        outbound = streamula.pipeline(
          streamula.tap('Server', -> server.trace),

De-context, strip off methods.

          streamula.act( (todo) ->
            for key, value of todo
              if _.isFunction(value)
                delete todo[key]
          ),
          streamula.tap("Server---->", -> server.trace),
          streamula.encode(),
          socketstream
        )
        @write = outbound.write

The inbound event stream, messages coming from a connected client.

* Spy for links. This informs you which clients need which messages by doing
a prefix match against all the linked data in this connection.
* Spy for client identifiers so we can route back client messages
* Spy for autoremove, which will be run on close
* Listen for events to reply on completion.
* Write to the server workstream, not that *this is not a pipe*, as multiple
clients are writing to this stream, and clients close

        client = null
        inbound = streamula.pipeline(
          socketstream,
          streamula.decode(),
          streamula.tap("Server<----", -> server.trace),
          streamula.map( (todo) ->
            if todo.path
              links[packPath(todo.path)] = true
            todo
          ),
          streamula.map( (todo) ->
            if server.connections[todo.__client__] and server.connections[todo.__client__] isnt connection
              outbound.write
                command: 'close'
                message: 'duplicate client'
              null
            else
              connection.client = client = todo.__client__
              server.connections[todo.__client__] = connection
              todo
          ),
          streamula.map( (todo) ->
            try
              if todo.command is 'autoremove'
                autoremove[packPath(todo.path)] =
                  command: 'remove'
                  path: parsePath(todo.path)
              if todo.command is 'closelink'
                for path, rm of autoremove
                  if path is packPath(todo.path)
                    delete autoremove[path]
                    server.workstream.write(rm)
              todo
            catch wtf
              console.log 'wtf', wtf
          ),
          streamula.map( (todo) ->
            server.workstream.write(todo)
          )
        )

        conn.on 'close', =>
          if server.connections[client] is connection
            delete server.connections[client]
          server.removeListener 'done', routeDone
          server.removeListener 'error', routeDone
          for ignore, todo of autoremove
            server.workstream.write(todo)
          server.emit 'close', connection

        conn.on 'error', (error) ->
          console.error 'connection error', client, error
        inbound.on 'error', (error) ->
          console.error 'connection error', client, error

    module.exports = Server
