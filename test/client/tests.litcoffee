
    window.holdopen = connToBeOrphaned = null
    should = chai.should()


    describe "Client Library", ->
        connToBeOrphaned = null
        before (done) ->
            connToBeOrphaned = variablesky.connect()
            connToBeOrphaned.once 'open', ->
                done()
        it "should auto reconnect", (done) ->
            #this should fire on the reconnect
            connToBeOrphaned.once 'open', ->
                done()
            #HAVOC, poke under the hood to pretend a disconnect
            connToBeOrphaned.dangerClose()
        it "should re-link data", (done) ->
            link = connToBeOrphaned
                .link('reco', (error, snapshot) ->
                    #this will be called three times
                    # * first link
                    # * save
                    # * re-link on the re-open
                    if this.count is 3
                        snapshot.should.eql('yeah')
                        done()
                )
                #force close, which will then re-open, then re-link...
                .save('yeah', (error, snapshot) ->
                    connToBeOrphaned.dangerClose()
                )

Test scenarios that use the client library from a browser.

    describe "Socket API", ->
        conn = null
        otherConn = null

Two connections, there are a lot of scenarios that are about cross browser
eventing, so we simulate these with two connections.

        before (done) ->
            conn = variablesky.connect()
            conn.on 'open', ->
                otherConn = variablesky.connect()
                otherConn.on 'open', ->
                    done()

        after (done) ->
            conn.close ->
                otherConn.close ->
                    done()

        it "can connect", (done) ->
            done()

        it "can get data at all", (done) ->
            conn.link('test', (snapshot) ->
                done()
            )

        it "can save data, and read it back", (done) ->
            conn.link('testback', (error, snapshot) ->
                if this.count is 2
                    snapshot.a.should.equal(1)
                    done()
            )
            .save(a: 1)

        it "gets undefined when you ask for stuff that isn't", (done) ->
            conn.link('mysterypants', (error, snapshot) ->
                should.not.exist(snapshot)
                done()
            )

        it "can remove previously saved data", (done) ->
            fired = {}
            link = conn.link('testremove')
            .save(a: 1, (error, snapshot) ->
                snapshot.should.eql(a:1)
            )
            .remove((error) ->
                should.not.exist(link.val)
                should.not.exist(conn.val.testremove)
                done()
            )

        it "will notify other connections on save", (done) ->
            conn.link('testcross', (error, snapshot) ->
                if this.count is 2
                    snapshot.should.eql('Hi')
                    done()
            )
            otherConn.link('testcross').save('Hi')

        it "will notify higher up / parent links when child data changes", (done) ->
            #a parent link, link fires on intial link, and then on the save
            #so we pop in a counter
            conn.link('parenty', (error, snapshot) ->
                #the parent sees the child value change. neat
                if this.count is 2
                    snapshot.hi.should.equal('mom')
                    done()
            )
            #a child save
            otherConn.link('parenty.hi').save('mom')

        it "will replicate deleted variables between connection", (done) ->
            conn.link('delicated', (error, snapshot) ->
                if this.count is 2
                    snapshot.should.eql(hi: 'mom')
                if this.count is 3
                    should.not.exist(snapshot)
                    should.not.exist(this.val)
                    should.not.exist(conn.val.delicated)
                    done()
                    #interlock this test so the final change does not fire
                    hasSaved = false
            )
            #the add remove sequence on another
            otherConn.link('delicated')
                .save(hi: 'mom')
                .remove()

        it "binds data in the sky to angular", (done) ->
            #pretend this is a controller, just get at the scope
            $scope = angular.element($("#testArea")).scope()
            #this sets up an automatic link that lives with the scope
            conn.linkToAngular('angular.test', $scope, 'variableFromSky')
            #and feed in changes from another connection, behold replication
            #simulation
            otherConn.link('angular.test').save('bird')
            #angular is all asynch, so keep on the lookout for the value
            $scope.eachDigest = ->
                input = $("#testSkyInput").val()
                if input is 'bird'
                    $scope.eachDigest = ->
                    done()
            $scope.$watch 'eachDigest()'

        it "binds data changes in UI through angular to the sky", (done) ->
            #pretend this is a controller, just get at the scope
            $scope = angular.element($("#testArea")).scope()
            #link to angular, there is a value callback that fires each time the
            #UI has digested a change. this is a bit redundant with $watch, but
            #lets you hook in
            conn.linkToAngular('angular.uptest', $scope, 'variableToSky')
            otherConn.link('angular.uptest', (error, value) ->
                if value and not this.done
                    value.should.eql('spacebird')
                    this.done = true
                    done()
            )
            #trigger a UI change
            angular.element($('#testSkyOutput'))
                .val('spacebird')
                .triggerHandler('change').triggerHandler('input')

        it "binds to arrays through angular and sends splices", (done) ->
            $scope = angular.element($("#testArea")).scope()
            conn.linkToAngular('angular.arraytest', $scope, 'skyarray')
            otherConn.link('angular.arraytest').save([])
            $scope.$watch 'skyarray', (newvalue, oldvalue) ->
                if newvalue?.length is 0
                    #push happening inside the watch, i.e. inside the $digest
                    #simulating what's up when you would really be binding
                    newvalue.push 'woot'
                if newvalue?.length is 1 and not this.done
                    newvalue.should.eql(['woot'])
                    this.done = true
                    done()

        it "lets you set a default value for angular", (done) ->
            $scope = angular.element($("#testArea")).scope()
            conn.linkToAngular('angular.goop', $scope, 'goop', {oh: 'yeah'})
            $scope.$watch 'goop', (value) ->
                if value and not this.done
                    this.done = true
                    value.should.eql({oh: 'yeah'})
                    done()




