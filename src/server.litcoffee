This is the main server object. This is a class to  hook to [connect] or
[express], I'm not all the way sure why you would want to, but you can make
multiple of these in a process and have separate sockets or rest url mount
points to them. I'd make some claim abut this being more testable, but I'd be
lying :)

    _ = require('lodash')
    path = require('path')
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
    es = require('event-stream')
    inspect = require('./util.litcoffee').inspect
    hookstream = require('./hookstream.litcoffee')
    commandstream = require('./commandstream.litcoffee')
    journalstream = require('./journalstream.litcoffee')
    websocket = require('websocket-stream')

    class Server extends EventEmitter
        constructor: (@options) ->
            @options = @options or {}
            @options.storageDirectory = @options.storageDirectory or path.join(process.cwd(), '.server')
            @options.journalDirectory = @options.journalDirectory or path.join(@options.storageDirectory, '.journal')
            @options.journal = if @options.journal? then @options.journal else true
            wrench.mkdirSyncRecursive(@options.storageDirectory)
            wrench.mkdirSyncRecursive(@options.journalDirectory)
            @blackboard = new Blackboard()
            @workstream = es.pipeline(

Enhance the todo turning it into a context for the rest of the processing stream.

              es.mapSync( (todo) =>
                _.extend todo,
                  prev: @blackboard.valueAt(todo.path)
                  abort: (message) ->
                    throw errors.HOOK_ABORTED(message)
                  link: (path, done) =>
                    new Link(@workstream, @blackboard, path, done)
              ),

And here is where the real processing happens:

* hooks
* commands
* hooks

              @beforeHooks = hookstream((todo) -> "#{todo.command}:#{packPath(todo.path)}"),
              @processor = commandstream(
                link: require('./commands/server/link')
                save: require('./commands/server/save')
                remove: require('./commands/server/remove')
                message: (todo, blackboard, done) =>
                  @emit todo.__to__, todo
                  done()
              , ((todo) -> todo.command)
              , @blackboard),
              @afterHooks = hookstream((todo) -> "#{todo.command}:#{packPath(todo.path)}"),

De-context, strip off methods we don't need any more.

              es.mapSync( (todo) ->
                delete todo.link
                delete todo.abort
                todo
              ),

Commands are written to a journal, providing durability and recovery.

              @journalstream = journalstream(@options),

Lots of tracing, server is done.

              es.mapSync( (todo) =>
                  if @trace
                    console.log '\nServer Done', inspect(todo)
                  @emit 'done', todo
              ),
            )

Clean server shutdown.

        shutdown: (done) ->
          @sock.close() if @sock
          @workstream.end()
          done()

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
          @connections = {}
          if not app.use
            throw errors.NOT_AN_APP()
          if @sock
            throw errors.ALREADY_LISTENING()

          url = url or '/variablesky'

If this looks like connect or express, install a client library handler and
and self check sample page. Detect connect/express with the presence of `use`.

          if app.use
            client = "#{path.join(url)}.client"
            app.use path.join(client, 'test'),
              connect.static(path.join(__dirname, '../test/client'))
            app.use client,  (req, res, next) ->
              res.setHeader('Content-Type', 'text/javascript')
              bundle = browserify()
                .transform(require('coffeeify'))
                .add(path.join(__dirname, 'client.litcoffee'))
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
                ret = new Connection(conn, this)
                @emit 'connected', ret
                ret

        traceOn: ->
          @trace = true
          this

A single server side connection instance, isolates the state of each client
from one another on the server.

    class Connection
      constructor: (conn, server) ->

When the server says it has journaled something, we need to route it to clients
that have a link to this path or a prefix of it so parent data knows about
child data changes.

        links = {}
        server.on 'done', routeDone = (todo) ->
          donepath = packPath(todo.path)
          for link in _.keys(links)
            if donepath.indexOf(link) is 0
              outbound.write todo

Streaming web sockets are go.

        socketstream = websocket(conn)

AutoRemove variables are tracked here by path.

        autoremove = {}

The outbound event stream, send messages along to a connected client.

        outbound = es.pipeline(
          es.mapSync( (todo) =>
            if server.trace
              console.log '\nServer---->', inspect(todo)
            todo
          ),
          es.stringify(),
          socketstream
        )

The inbound event stream, messages coming from a connected client.

* Spy for links. This informs you which clients need which messages by doing
a prefix match against all the linked data in this connection.
* Spy for client identifiers so we can route back client messages
* Spy for autoremove, which will be run on close
* Listen for events to reply on completion.
* Write to the server workstream, not that *this is not a pipe*, as multiple
clients are writing to this stream, and clients close

        client = null
        inbound = es.pipeline(
          es.parse(),
          es.mapSync( (todo) =>
            if server.trace
                console.log '\nServer<----', inspect(todo)
            todo
          ),
          es.mapSync( (todo) ->
            if todo.path
              links[packPath(todo.path)] = true
            todo
          ),
          es.map( (todo, callback) ->
            if client is todo.__client__
              #no change
            else
              if client
                server.removeListener(client, outbound.write)
              client = todo.__client__
              server.on(client, outbound.write)
            callback(null, todo)
          ),
          es.mapSync( (todo) ->
            if todo.command is 'autoremove'
              autoremove[packPath(todo.path)] =
                command: 'remove'
                path: parsePath(todo.path)
            todo
          ),
          es.mapSync( (todo) ->
            if todo.command is 'closelink'
              for path, rm of autoremove
                if path is packPath(todo.path)
                  delete autoremove[path]
                  server.workstream.write(rm)
            todo
          ),
          es.mapSync( (todo) ->
              server.workstream.write(todo)
              undefined
          )
        )
        socketstream.pipe(inbound)

        conn.on 'close', =>
          server.removeListener 'done', routeDone
          server.removeListener client, outbound.write
          for ignore, todo of autoremove
            server.workstream.write(todo)

        conn.on 'error', (error) =>
          console.error 'connection error', client, error

    module.exports = Server
