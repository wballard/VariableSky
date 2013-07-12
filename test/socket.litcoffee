Test connection and action over a streaming socket.

    sky = require('../index')
    request = require 'supertest'
    path = require('path')
    should = require('chai').should()
    Browser = require('zombie')

    options =
        storageDirectory: path.join __dirname, '.test'

    describe "Socket API", ->
        app = null
        skyserver = null
        before ->
            app = require('express')()
            server = require('http').createServer(app)
            skyserver = new sky.Server(options)
            skyserver.listen server
            server.listen 9999
        after (done) ->
            skyserver.shutdown done
        it "serves a browser client library page", (done) ->
            browser = new Browser()
            browser.debug = true
            browser.runScripts = true
            browser.visit 'http://localhost:9999/variablesky.client.html', ->
                browser.success.should.be.ok
                done()
            , (err) ->
                if err
                    console.log 'ERRRRR', err
                    done()
        it "serves a browser client library", (done) ->
            request(app)
                .get('/variablesky/client')
                .expect(200)
                .expect('Content-Type', /javascript/)
                .expect(/Client/)
                .end (err, res) ->
                    client = Function(res.text).call(this)
                    end()

