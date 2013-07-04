The most basic interactions are with REST, this makes a workable server, the only
sad part is that it doesn't have events and thus no replication.

    request = require 'supertest'
    app = require('express')()
    sky = require('../index')
    app.use '/mounted', new sky.Server().rest

The REST API.

    describe "REST API", ->
        it "404s when you ask for the unknown", (done) ->
            request(app)
                .get('/mounted/message')
                .expect(404)
                .expect({name: 'NOT_FOUND', message: 'message'}, done)
        it "will let you PUT data", (done) ->
            request(app)
                .post('/mounted/message')
                .send({hi: "mom"})
                .expect(200, done)
        it "will then GET that data back", (done) ->
            request(app)
                .get('/mounted/message')
                .expect('Content-Type', /json/)
                .expect(200)
                .expect({hi: "mom"}, done)
        it "will let you DELETE", (done) ->
            request(app)
                .del('/mounted/message/hi')
                .expect(200, done)
        it "will let you PUT individual properties", (done) ->
            request(app)
                .post('/mounted/message/hi')
                .send("dad")
                .expect(200, done)
        it "will then let you GET again", (done) ->
            request(app)
                .get('/mounted/message')
                .expect('Content-Type', /json/)
                .expect(200)
                .expect({hi: "dad"}, done)
        it "will let you POST, adding to an array", (done) ->
            request(app)
                .post('/mounted/message/from')
                .send('me')
                .expect(200, done)
        it "will let you POST to an array again", (done) ->
            request(app)
                .post('/mounted/message/from')
                .send('you')
                .expect(200, done)
        it "will let you GET an array", (done) ->
            request(app)
                .get('/mounted/message/from')
                .expect('Content-Type', /json/)
                .expect(200)
                .expect(['me', 'you'], done)
        it "will let you DELETE an array index", (done) ->
            request(app)
                .get('/mounted/message/from/0')
                .expect(200, done)
        it "will then let you GET an array", (done) ->
            request(app)
                .get('/mounted/message/from')
                .expect('Content-Type', /json/)
                .expect(200)
                .expect(['you'], done)
        it "will not let you POST to a non array", (done) ->
            request(app)
                .post('/mounted/message/hi')
                .send('me')
                .expect(405)
                .expect('Allow', 'GET, PUT, DELETE')
                .end(done)
