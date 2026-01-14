#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                    Implements macros and utility functions for memory managment and GC operations
#------------------------------------------------------------------------------------------------------------------------------------------------------

#Macro that wraps a block of code in a gcsafe block
macro gcSafe(body: untyped): untyped =
    result = quote do:
        {.cast(gcsafe).}:
            `body`

#Defines a macro for simplified definitions of destroy functions for both ref
macro destructor(t: typedesc, body: untyped): untyped =
    let x = newIdentNode("x")
    
    when t is ref:
        result = quote do:
            proc `=destroy`(`x`: var typeof `t`()[]) =
                `body`
    else:
        result = quote do:
            proc `=destroy`(`x`: var `t`) =
                `body`


macro `+`(a: pointer, b: int): pointer =
    result = quote do:
        cast[pointer](cast[int](`a`) + `b`)