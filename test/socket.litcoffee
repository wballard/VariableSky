Test connection and action over a streaming socket.

    sky = require('../index')
    path = require('path')
    sockjsclient = require('sockjs-client')

    options =
        storageDirectory: path.join __dirname, '.test'

    describe "Socket API", ->
        app = null
        server = null
        before ->
            app = require('express')()
            server = require('http').createServer(app)
            sky = new sky.Server(options)
            sky.listen server
            server.listen 9999
        after (done) ->
            sky.shutdown done
        it "Connects at all", (done) ->
            sock = sockjsclient.create('http://localhost:9999/variablesky')
            sock.on 'connection', ->
                console.log 'open'
                done()

