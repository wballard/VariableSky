Remove content from the blackboard. This works on properties and array indexes
so is smart enough to tell the difference.

    _ = require('lodash')

    module.exports = (todo, blackboard, done) ->
        if todo?.href.length
            at = blackboard
            for segment in _.initial(todo.href)
                if at[segment]
                    at = at[segment]
                else
                    #fortunately for us, it is already deleted!
                    return done(null, null)
            if _.isArray(at)
                index = Number(_.last(todo.href))
                if _.isNumber(index)
                    #array index, the normal
                    at.splice(index, 1)
                else
                    #yep, you can put properties on array, odd but true...
                    delete at[_.last(todo.href)]
            else
                delete at[_.last(todo.href)]
        return done(null, null)
