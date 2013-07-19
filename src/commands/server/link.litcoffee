Link to content on the blackboard, returning it if possible, erroring
otherwise.

    module.exports = (todo, blackboard, done) ->
        todo.val = blackboard.valueAt(todo.path)
        done null

This is a read command, no sense clogging up the journal with it.

    module.exports.DO_NOT_JOURNAL = true
