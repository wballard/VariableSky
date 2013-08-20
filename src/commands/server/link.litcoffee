Link to content on the blackboard, returning it if possible, erroring
otherwise.

    module.exports = (todo, blackboard, done) ->
      todo.val = blackboard.valueAt(todo.path)

This is a read command, no sense clogging up the journal with it.

      todo.__no_journal__ = true
      done()
