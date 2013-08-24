Merge content into the bloackboard at a path location.

Merge will create objects as needed, take a look at `save`.

    _ = require('lodash')

    module.exports = (todo, blackboard) ->
      if todo?.path.length
        at = blackboard
        for segment in _.initial(todo.path)
          if at[segment]
            at = at[segment]
          else
            at = at[segment] = {}
        if not at[_.last(todo.path)]
          at[_.last(todo.path)] = {}
        if todo.val
          at[_.last(todo.path)] = _.extend at[_.last(todo.path)], todo.val
        if todo.diff
          adiff.patch(at[_.last(todo.path)], todo.diff, true)
