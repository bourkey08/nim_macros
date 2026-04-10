#Implements standard utility functions and macros (with, log, swap, toString ect)
#Set this variable to toggle debug mode
import std/[macros]

when not defined(standalone):
    import os
    
    #Enable the profiler if the compileOption is set
    when compileOption("profiler"):
        import nimprof

    macro with(args: untyped, body: untyped): untyped =
        #Split the components of the args and body into variables
        let varname = args[2]
        let funct = args[1]
        
        #Check if the function call is open, this is used to determin if the with clause is for working with a file so we can apply additional rules
        var IsFile = false;
        if $args[1][0] == "open":
            IsFile = true;

        result = quote do:
            var `varname` = `funct`
            `body`       
            
        #If this is a file add a close method call
        if IsFile:
            result = quote do:
                `result`  
                `varname`.close()

    #Implement a logging macro, this will then handle adding echos when in debug mode only
    macro log(args: untyped): untyped =
        when declared(debug):
            when debug:
                result = quote do:
                    echo `args`;
            else:
                result = quote do:
                    discard
        else:
            quote do:
                discard

    macro importer(args: untyped): untyped =
        #Define a list we will build up with the imports
        var resp: seq[NimNode] = @[]

        args.expectKind nnkStmtList

        for entry in args:
            entry.expectKind nnkInfix
            entry.expectLen 3
            entry[2].expectKind nnkIdent

            let moduleName = entry[1]
            let alias = entry[2]   

            let importStatment = quote do:
                from `moduleName` as `alias` import nil

            resp.add(
                importStatment
            )         

        for entry in resp:
            result = quote do:
                `entry`
                `result`

        result.copyLineInfo(args)

        #If macroDebug is defined and macroDebug is true then log the tree representation of the result
        when declared(macroDebug):
            when macroDebug:
                hint result.treeRepr

when sizeof(int) >= 4:
    import regex

    func`reG`(pat: string, data: string): seq[string] {.inline.} =
        var resp: seq[string] = @[]
        let exp = re2(pat)

        for entry in regex.findAll(data, exp):
            for capt_group in entry.captures:
                resp.add(data[capt_group])

        return resp

proc alloca(n: int): pointer {.importc, header: "<alloca.h>".}
proc malloc(n: int): pointer {.importc, header: "<stdlib.h>".}
proc free(p: pointer) {.importc, header: "<stdlib.h>".}

#Swap 2 variables
template swap(x: untyped, y: untyped): untyped =
    let tmp = x;
    x = y;
    y = tmp;

#Shortcut for raising a generic exception with a message
template throw(msg: string): untyped = 
    raise newException(Exception, msg)


#Define a c style ternary operator, we cant use ? : in nim so we have to implement our own
macro `tern`(cond: typed, trueVal: typed, falseVal: typed): untyped =
    quote do:
        var resp: type(`trueVal`)
        if `cond`:
            resp = `trueVal`
        else:
            resp = `falseVal`
        resp

#C like ternary operator with 2 branches
macro `?`(cond: bool, body: varargs[untyped]): untyped =   
    if body.len != 2:
        throw "The ternary operator requires exactly two branches"

    let left = body[0]
    let right = body[1]

    result = quote do: 
        tern(`cond`, `left`, `right`)

#Behaves like the python pass keyword (does nothing)
template pass(): untyped =
    discard 1

#Macro to define variables that should have there value inlined (but cant be constants)
macro def(x: untyped) =
    result = newStmtList()

    #Split the input into ident and val
    if x[0].kind != nnkIdent:
        raise newException(ValueError, "Identifier expected")
    let ident = x[0]
    let val = x[1]
    result.add quote do:
        template `ident`(): untyped =
            `val`

#Macro to get the size of a pointer type object at compile time
macro psizeof*(t: typedesc): untyped =
    let ty = t.getType()

    result = quote do:
        when compiles(create(`ty`)[][]):
            let obj = create(`ty`)
            sizeof (obj[][])
        else:
            sizeof (`t`)


#Takes a look in the format expandLoop ident, {seq of values} and applys the body to each value in the seq
macro expandLoop(v: untyped, rng: untyped, body: untyped): untyped =
    result = newStmtList()

    if v.kind != nnkIdent:
        raise newException(ValueError, "First argument to expandLoop must be an identifier")

    if rng.kind != nnkCurly:
        raise newException(ValueError, "Second argument to expandLoop must be a bracket expression")
    
    for child in rng:
        result.add quote do:
            block:
                let `v` = `child`
                `body`
