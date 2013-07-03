Error making macros.

    module.exports =
        NOT_FOUND: (href) ->
            name: "NOT_FOUND"
            message: href.join('/')
