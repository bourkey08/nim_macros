#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                    Implements macros and utility functions for memory managment and GC operations
#------------------------------------------------------------------------------------------------------------------------------------------------------

##Macro that wraps a block of code in a gcsafe block
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

##Defines a + operation for pointers to allow pointer arithmetic
macro `+`(a: pointer, b: int): pointer =
    result = quote do:
        cast[pointer](cast[int](`a`) + `b`)

##Defines a - operation for pointers to allow pointer arithmetic
macro `-`(a: pointer, b: int): pointer =
    result = quote do:
        cast[pointer](cast[int](`a`) - `b`)

##Defines a macro for cleaner definitions of unsafe optimizations with a safe alternative
#Eg copyMem(val.addr + 6, data.addr, val.len) or val[6..^1] = data)
macro unsafeOpts(body: untyped, elsebody: untyped): untyped =
    if elsebody.kind == nnkElse:
        when defined(unsafeOpts):
            result = quote do:
                `body`
        else:
            #Strip the else node to get the actual body
            let eBody = elsebody[0]
            result = quote do:
                `eBody`