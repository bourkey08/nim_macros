import macros

#Allow python and js style string concatenation
template `+=`(s: var string, x: string) =
    s = s & x


#Implement a macro for casting an array to a string
macro toString(args: untyped): untyped = 
    result = quote do:
        var stringValue = ""

        for b in `args`:
            stringValue.add(b.char)

        stringValue

macro u8(str: string): untyped =    
    quote do:
        var resp: seq[byte] = @[]

        for c in `str`:
            resp.add(byte char(c))

        resp
