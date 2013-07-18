Remove content from the blackboard. This works on properties and array indexes
so is smart enough to tell the difference.

    _ = require('lodash')

    module.exports = (todo, blackboard, done) ->
        if todo?.path.length
            at = blackboard
            for segment in _.initial(todo.path)
                if at[segment]
                    at = at[segment]
                else
                    #fortunately for us, it is already deleted!
                    return done null
            if _.isArray(at)
                index = Number(_.last(todo.path))
                if _.isNumber(index)
                    #array index, the normal
                    at.splice(index, 1)
                else
                    #yep, you can put properties on array, odd but true...
                    delete at[_.last(todo.path)]
            else
                todo.val = at[_.last(todo.path)]
                if todo.__trace__
                    console.log 'remove', todo.path
                delete at[_.last(todo.path)]
        done null
