Save content into the blackboard at an object location determined
by the path.

Save always works, it creates object along the path as needed, and stomps
data in its way if needed. It is **ruthless** and **relentless**.
Well, maybe not, maybe it is just _dedicated_.

    _ = require('lodash')

    module.exports = (todo, blackboard, done) ->
        if todo?.path.length
            at = blackboard
            for segment in _.initial(todo.path)
                if at[segment]
                    at = at[segment]
                else
                    at = at[segment] = {}
            at[_.last(todo.path)] = todo.val
        done null, todo
