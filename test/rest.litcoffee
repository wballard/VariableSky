The most basic interactions are with REST, this makes a workable server, the only
sad part is that it doesn't have events and thus no replication.

    request = require 'supertest'
    app = require('express')()

And a 'fake' serve with the variablesky middleware.

    describe "REST API", ->
        it "404s when you ask for the unknown", (done) ->
            request(app)
                .get('/')
                .expect(404, done)
