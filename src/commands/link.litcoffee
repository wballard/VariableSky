Link to content on the blackboard, returning it if possible, erroring
otherwise.

    module.exports = (todo, blackboard, done) ->
        at = blackboard
        for segment in todo.href
            if at[segment]
                at = at[segment]
            else

If you don't find anything, come back undefined -- not null.

                delete todo.val
                return done null, todo

But if we get all the way down to the tail of the href, then we have a null,
this is _a value_, not like undefined.

        todo.val = at
        done null, todo

This is a read command, no sense clogging up the journal with it.

    module.exports.DO_NOT_JOURNAL = true
