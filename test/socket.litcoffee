Test connection and action over a streaming socket.

    sky = require('../index')
    path = require('path')
    should = require('chai').should()
    Browser = require('zombie')
    wrench = require('wrench')
    connect = require('connect')

    options =
        storageDirectory: path.join __dirname, '.sockettest'

    describe "Socket API", ->
        app = null
        skyserver = null
        before (done) ->
            wrench.rmdirSyncRecursive options.storageDirectory, true
            app = connect()
            server = require('http').createServer(app)
            skyserver = new sky.Server(options)
            skyserver.listen app, server
            server.listen(9999, done)
        after (done) ->
            skyserver.shutdown done
        it "serves a browser client self test page", (done) ->
            browser = new Browser()
            browser.debug = true
            browser.runScripts = true
            browser.visit 'http://localhost:9999/variablesky.client/test/index.html', ->
                browser.success.should.be.ok
                done()
            , (err) ->
                if err
                    console.log 'ERRRRR', err
                    done()
