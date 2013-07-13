Test scenarios that use the client library from a browser.

    describe "Socket API", ->
        conn = null
        otherConn = null
        should = chai.should()

Two connections, there are a lot of scenarios that are about cross browser
eventing, so we simulate these with two connections.

        before (done) ->
            conn = variablesky.connect()
            conn.on 'connection', ->
                otherConn = variablesky.connect()
                otherConn.on 'connection', ->
                    done()

        it "can connect", (done) ->
            done()

        it "can get data at all", (done) ->
            conn.link('/test').on 'link', (snapshot) ->
                done()

        it "can save data, and read it back", (done) ->
            conn.link('/test').on 'save', (snapshot) ->
                snapshot.a.should.equal(1)
                done()
            conn.save a: 1

        it "can remove previously saved data", (done) ->
            conn.link('/test').on 'remove', (snapshot) ->
                should.not.exist(snapshot)
            conn.save(a: 1).remove()

