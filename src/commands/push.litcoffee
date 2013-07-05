Push on to the end of an array. This will make an array if it doesn't exist
in a sense trying really hard like save.

What it won't do is try to push to a non-array, that's an error.

    _ = require('lodash')
    errors = require('../errors')

    module.exports = (todo, blackboard, done) ->
        if todo?.href.length
            at = blackboard
            for segment in _.initial(todo.href)
                if at[segment]
                    at = at[segment]
                else
                    at = at[segment] = {}
            tail = at[_.last(todo.href)]
            if not tail
                tail = at[_.last(todo.href)] = []
            if _.isArray(tail)
                tail.push(todo.content)
            else
                return done errors.NOT_AN_ARRAY(todo.href)
        done()