A client side splice runs the splice, but also reads back the entire array into
the `val`.

    splice = require('../server/splice.litcoffee')
    link = require('../server/link.litcoffee')

    module.exports = (todo, blackboard, done) ->
        splice todo, blackboard, (error) ->
            if error
                done error
            else
                link todo, blackboard, (error) ->
                    if error
                        done error
                    else
                        done undefined
