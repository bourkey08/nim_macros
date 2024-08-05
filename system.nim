#Implements utility functions and macros for system operations
import std/[envvars, macros, strutils, sequtils]
#Takes a string containing 1 or more enviromental variables and replaces them with there values before returning the string
proc parseEnvString(str: string): string {.inline.} =
    var result = ""

    var i=0;
    var buff = ""
    var inVar: bool = false
    while i < str.len:
        #If we have found a % then check if this is the start or the end of an env var
        if str[i] == '%':
            #End of an existing env var
            if buff.len > 0:
                result.add(getEnv(buff))
                buff = ""
                inVar = false
            else:
                inVar = true
        else:
            if inVar:#If we are part way through an enviomental variable then add the char to the buffer for that variable
                buff.add(str[i])
            else:#Otherwise add it directly to the output string
                result.add(str[i])
        i += 1

    return result  


#Takes a path and splits it into its folders/file
macro splitPath(str: string): seq[string] =
    quote do:
        var pathResult: seq[string] = @[]
        var buff = ""

        for i in 0..<`str`.len:
            if `str`[i] == '/' or `str`[i] == '\\':
                if buff.len > 0:
                    pathResult.add(buff)
                    buff = ""
            else:
                buff.add(`str`[i])

        if buff.len > 0:
            pathResult.add(buff)

        pathResult

#Splits a string into the filename/path and the extension
macro splitExt(str: string): seq[string] =
    quote do:
        var extResult: seq[string] = @[]
        var buff = ""

        #Iterate backwards until we find the first . or a folder seperator
        var i=`str`.len-1
        while i >= 0:
            if `str`[i] == '.':
                if buff.len > 0:
                    extResult.add(buff)
                    buff = ""
            elif `str`[i] == '/' or `str`[i] == '\\':
                break
            else:
                buff = `str`[i] & buff#This is backwards to get the extension in the correct order

            i = i - 1

        #Now if there is any remaining data then add it to the first element
        while i >= 0:
            buff = `str`[i] & buff
            i -= 1

        #Now add the filename to the result at the start of the list (even if its blank)
        buff & extResult

#Splits a string into the folder path and filename
macro splitFolder(str: string): seq[string] =
    quote do:
        var folderResult: seq[string] = @[]
        var buff = ""

        #Iterate backwards until we find the first folder seperator
        var i=`str`.len-1
        while i >= 0:
            if `str`[i] == '/' or `str`[i] == '\\':
                if buff.len > 0:
                    folderResult.add(buff)
                    buff = ""
                break
            else:
                buff = `str`[i] & buff#This is backwards to get the extension in the correct order

            i = i - 1

        #Now if there is any remaining data then add it to the first element
        while i >= 0:
            buff = `str`[i] & buff
            i -= 1

        #Now add the filename to the result at the start of the list (even if its blank)
        buff & folderResult
