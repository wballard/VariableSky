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
