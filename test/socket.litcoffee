Test connection and action over a streaming socket.

    sky = require('../index')
    request = require 'supertest'
    path = require('path')
    should = require('chai').should()

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
        it "serves a browser client library", (done) ->
            request(app)
                .get('/variablesky/client')
                .expect(200)
                .expect('Content-Type', /javascript/)
                .expect(/Client/)
                .end done
        it "connects at all", (done) ->
            client = sky.connect('http://localhost:9999/variablesky')
            client.on 'connection', ->
                done()
        it "links to data that is undefined", (done) ->
            client = sky.connect('http://localhost:9999/variablesky')
            link = client
                .link('/sample')
                .on 'link', (val) ->
                    should.not.exist val
                    done()

