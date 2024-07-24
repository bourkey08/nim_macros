import macros, strutils

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


#Macro for converting a single int in the range 0-15 to a hex char
template `toHex4bit`(args: typed): untyped = 
    var result = ""
    case byte(`args`):
    of 0:
        result = "0"
    of 1:
        result = "1"
    of 2:
        result = "2"
    of 3:
        result = "3"
    of 4:
        result = "4"
    of 5:
        result = "5"
    of 6:
        result = "6"
    of 7:
        result = "7"
    of 8:
        result = "8"
    of 9:
        result = "9"
    of 10:
        result = "A"
    of 11:
        result = "B"
    of 12:
        result = "C"
    of 13:
        result = "D"
    of 14:
        result = "E"
    of 15:
        result = "F"
    else:
        raise newException(ValueError, "Invalid value for toHex4bit")

    result

#Macro for converting a single int character in the range 0-F to a 4 bit int
template `fromHex4bit`(args: typed): untyped =
    var result = 0
    case `args`:
    of '0':
        result = 0
    of '1':
        result = 1
    of '2':
        result = 2
    of '3':
        result = 3
    of '4':
        result = 4
    of '5':
        result = 5
    of '6':
        result = 6
    of '7':
        result = 7
    of '8':
        result = 8
    of '9':
        result = 9
    of 'A':
        result = 10
    of 'B':
        result = 11
    of 'C':
        result = 12
    of 'D':
        result = 13
    of 'E':
        result = 14
    of 'F':
        result = 15
    else:
        raise newException(ValueError, "Invalid value for fromHex4bit")

    result

#Macros for converting a string or a sequence/array of bytes into a hex string
macro toHex(args: string): string = 
    quote do:
        var resp = ""

        for b in `args`:
            let lower = byte(b) and 0xF
            let upper = byte(b) shr 4

            resp += upper.toHex4bit
            resp += lower.toHex4bit

        resp

macro toHex(args: openArray[byte]): string = 
    quote do:
        var resp = ""

        for b in `args`:
            let lower = b and 0xF
            let upper = b shr 4

            resp += upper.toHex4bit
            resp += lower.toHex4bit

        resp

#Macros for parsing a hex string into a sequence of bytes
macro fromHex(args: string): openArray[byte] = 
    quote do:
        var resp: seq[byte] = @[]

        for i in 0..(`args`.len div 2) - 1:            
            let upper = `args`[i * 2].fromHex4bit
            let lower = `args`[i * 2 + 1].fromHex4bit

            resp.add(byte(upper shl 4 or lower))

        resp

#Shortcut functions for checking the contents of strings match specific criteria
macro isdigit(val: string): bool =
    quote do:
        var result = true

        for c in `val`:
            let value = ord(c)
            if value < 48 or value > 57:
                result = false
                break

        result

macro isalnum(val: string): bool =
    quote do:
        var result = true

        for c in `val`:
            let value = ord(c)
            if (value < 48 or value > 57) and (value < 65 or value > 90) and (value < 97 or value > 122):
                result = false
                break

        result

macro isalpha(val: string): bool =
    quote do:
        var result = true

        for c in `val`:
            let value = ord(c)
            if (value < 65 or value > 90) and (value < 97 or value > 122):
                result = false
                break

        result

macro isupper(val: string): bool =
    quote do:
        var result = true

        for c in `val`:
            let value = ord(c)
            if value < 65 or value > 90:
                result = false
                break

        result

macro islower(val: string): bool =
    quote do:
        var result = true

        for c in `val`:
            let value = ord(c)
            if value < 97 or value > 122:
                result = false
                break
        result