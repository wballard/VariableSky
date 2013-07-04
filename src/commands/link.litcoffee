Link to content on the blackboard, returning it if possible, erroring
otherwise.

    errors = require('../errors')

    module.exports = (todo, blackboard, done) ->
        at = blackboard
        for segment in todo.href
            if at[segment]
                at = at[segment]
            else
                done(errors.NOT_FOUND(todo.href))
                return
        done(null, at)

This is a read command, no sense clogging up the journal with it.

    module.exports.DO_NOT_JOURNAL = true
