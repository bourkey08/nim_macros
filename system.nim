#Implements utility functions and macros for system operations
import std/envvars

#Takes a string containing 1 or more enviromental variables and replaces them with there values before returning the string
func parseEnvString(str: string): string {.inline.} =
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