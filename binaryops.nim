#Implements macros/functions for binary operations
import macros
import bitops
import math

#Define a few operators

#Rotate Right
template `rotateright`(x: untyped, y: untyped): untyped =
    when x is uint16:
        (`x` shr `y`) + ((`x` shl (uint16(16) - `y`)))

    elif x is int16:
        (`x` shr `y`) + (`x` & (int16(2) ** (int16(32) - `y`)))

    elif x is uint32:
        (`x` shr `y`) + (`x` & (uint32(2) ** (uint32(32) - `y`)))

    elif x is int32:
        (`x` shr `y`) + (`x` & (int32(2) ** (int32(32) - `y`)))

    elif x is uint64:
        (`x` shr `y`) + (`x` & (uint64(2) ** (uint64(32) - `y`)))

    elif x is int64:
        (`x` shr `y`) + (`x` & (int64(2) ** (int64(32) - `y`)))
    
    else:
        raise ValueError("Invalid type for rotateleft")

macro `>>>`(x, y: untyped): untyped =    
    newCall(bindSym"rotateright", x, y)

#Rotate left
template `rotateleft`(x: untyped, y: untyped): untyped =
    when x is uint16:
        (`x` shl `y`) + (`x` shr (uint16(16) - `y`))

    elif x is int16:        
        (`x` shl `y`) + (`x` shr (int16(16) - `y`))

    elif x is uint32:
        (`x` shl `y`) + (`x` shr (uint32(32) - `y`))

    elif x is int32:
        (`x` shl `y`) + (`x` shr (int32(32) - `y`))

    elif x is uint64:
        (`x` shl `y`) + (`x` shr (uint64(64) - `y`))

    elif x is int64:
        (`x` shl `y`) + (`x` shr (int64(64) - `y`))

    else:
        raise ValueError("Invalid type for rotateleft")

macro `<<<`(x, y: untyped): untyped =    
    newCall(bindSym"rotateleft", x, y)

macro `<<`(x, y: untyped): untyped =    
    #result = nnkInfix.newTree(newIdentNode("shl"), x, y)
    result = quote do:
        (`x` shl `y`)

macro `>>`(x, y: untyped): untyped =
    #result = nnkInfix.newTree(newIdentNode("shr"), x, y)
    result = quote do:
        (`x` shr `y`)

macro `%`(x, y: untyped): untyped =
      result = quote do:          
          `x` mod `y`         

macro `&`(x: typed, y: typed): untyped =
    #If both x and y are int literals
    if x.kind == nnkIntLit and y.kind == nnkIntLit:
        result = quote do:
            `x` and `y`

    #Otherwise if just x is an int literal
    elif x.kind == nnkIntLit:
        #Get the type of y
        let t = y.getType()

        #And convert x to that type
        result = quote do:
            `y` and `t`(`x`)

    #Otherwise if just y is an int literal
    elif y.kind == nnkIntLit:
        #Get the type of x
        let t = x.getType()

        #And convert y to that type
        result = quote do:
            `x` and `t`(`y`)        

    else:#If neither x nor y are int literals
        result = quote do:
            `x` and `y`    

template `power`(x: untyped, y: untyped): untyped =
    
    when x is not float64|float32 and y is not float64|float32:
        x ^ y
    else:
        pow(float(x), float(y))

macro `**`(x: typed, y: typed): untyped = 
    newCall(bindSym"power", x, y)


#Define a floor division operator
template `floordiv`(x: untyped, y: untyped): untyped =
    when x is not float64|float32 and y is not float64|float32:
        math.floor(x / y)
    else:
        math.floor(float64(x) / float64(y))

macro `//`(x: typed, y: typed): untyped = 
    newCall(bindSym"floordiv", x, y)

#Define ! as a not operator
macro `!`(x: untyped): untyped =
    result = quote do:
        not `x`

template `||`(x: untyped, y: untyped): untyped =
    `x` or `y`

template `&&`(x: untyped, y: untyped): untyped =
    `x` and `y`

#Define assignment operators
macro `^=`(x, y: untyped): untyped =
    hint $x.kind
    result = quote do:
        `x` = `x` xor `y`

macro `&=`(x, y: untyped): untyped =
    result = quote do:
        `x` = `x` and `y`

macro `|=`(x, y: untyped): untyped =
    result = quote do:
        `x` = `x` or `y`

macro `>>=`(x, y: untyped): untyped =
    result = quote do:
        `x` = `x` >> `y`

macro `<<=`(x, y: untyped): untyped =
    result = quote do:
        `x` = `x` << `y`

macro `**=`(x, y: untyped): untyped =
    result = quote do:
        `x` = `x` ** `y`

macro `%=`(x, y: untyped): untyped =
    result = quote do:
        `x` = `x` % `y`

macro `:=`(x, y: untyped): untyped =
    result = quote do:
        var `x` = `y`

#Defime increment operators
macro `++`(x: untyped): untyped =
    result = quote do:
        `x` += 1

macro `--`(x: untyped): untyped =
    result = quote do:
        `x` -= 1

#Define constants for modulo operations
const mod64: uint64 = (uint64(2) ** uint64(64)) - 1
const mod32: uint32 = (uint32(2) ** uint32(32)) - 1
const mod16: uint16 = (uint16(2) ** uint16(16)) - 1
const mod8: uint8 = (uint8(2) ** uint8(8)) - 1
