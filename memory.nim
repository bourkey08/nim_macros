#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                    Implements macros and utility functions for memory managment and GC operations
#------------------------------------------------------------------------------------------------------------------------------------------------------

#Defines a macro for simplified definitions of destroy functions for both ref
template destructor(t: typedesc, body: untyped): untyped =
    when t is ref:
        proc `=destroy`(x: typeof `t`()[]) =
            `body`
    else:
        proc `=destroy`(x: `t`) =
            `body`

#Macro that wraps a block of code in a gcsafe block
macro gcSafe(body: untyped): untyped =
    result = quote do:
        {.cast(gcsafe).}:
            `body`