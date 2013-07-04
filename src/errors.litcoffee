Error making macros.

    module.exports =
        NOT_FOUND: (href) ->
            name: "NOT_FOUND"
            message: href.join('/')
        PARSE_ERROR: (err) ->
            name: "PARSE_ERROR"
            message: "This was no parseable. Sorry"
            err: err
        NOT_AN_ARRAY: (href) ->
            name: "NOT_AN_ARRAY"
            message: href.join('/')
