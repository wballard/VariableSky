describe("Socket API", function() {
    var conn;
    should = chai.should();

    before(function(done){
        conn = variablesky.connect();
        conn.on('connection', function(){
            done();
        });
    });

    it("can connect", function(done){
        done();
    });

    it("can get undefined data", function(done){
        conn.link('/test')
        .on('link', function(snapshot){
            done();
        });
    });

    it("can save data, then read it back", function(done){
        conn.link('/test')
        .on('save', function(snapshot){
            snapshot.a.should.equal(1);
            done();
        })
        .save({'a': 1});
    });

    it("can save data, then remove data", function(done){
        conn.link('/test')
        .on('remove', function(snapshot){
            should.not.exist(snapshot);
            done();
        })
        .save({'a': 1})
        .remove();
    });
})
