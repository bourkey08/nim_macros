#Implements standard utility functions and macros (with, log, swap, toString ect)
#Set this variable to toggle debug mode
import macros, os
import regex

proc alloca(n: int): pointer {.importc, header: "<alloca.h>".}
proc malloc(n: int): pointer {.importc, header: "<stdlib.h>".}

#Enable the profiler if the compileOption is set
when compileOption("profiler"):
    import nimprof

#Swap 2 variables
template swap(x: untyped, y: untyped): untyped =
    let tmp = x;
    x = y;
    y = tmp;

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

template`reG`(pat: string, data: string): untyped =
    var result: seq[string] = @[]
    let exp = re2(pat)

    for entry in regex.findAll(data, exp):
        for capt_group in entry.captures:
            result.add(data[capt_group])

    result

#Define a c style ternary operator, we cant use ? : in nim so we have to implement our own
macro `tern`(cond: typed, trueVal: typed, falseVal: typed): untyped =
    quote do:
        var resp: type(`trueVal`)
        if `cond`:
            resp = `trueVal`
        else:
            resp = `falseVal`
        resp
