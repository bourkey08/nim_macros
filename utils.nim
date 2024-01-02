#Implements standard utility functions and macros (with, log, swap, toString ect)
#Set this variable to toggle debug mode
const debug = true

import macros

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
    when debug:
        result = quote do:
            echo `args`;
    else:
        result = quote do:
            discard

#Implement a macro for casting an array to a string
macro toString(args: untyped): untyped = 
    result = quote do:
        var stringValue = ""

        for b in `args`:
            stringValue.add(b.char)

        stringValue
