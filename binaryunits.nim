import macros, strutils

#Takes a string containing a value with a unit and converts this to bytes/bits
func parseBinaryUnits(text: string, retBits: static[bool]=false): int {.inline.} =
    #Define 2 sequences we will add all characters to based on if they are numbers
    var intchars: seq[char] = @[]
    var unitchars: seq[char] = @[]

    for i in text:
        if i.isdigit:
            intchars.add i

        else:
            unitchars.add i

    #Now join the sequences into 2 strings
    let intstr = intchars.join()
    let unitstr = unitchars.join()

    #Based on the unitstr calculate a multiplier
    var multiplier: int = 1#Default to 1 if there is no unit (assumes its in byte)
    
    #Convert the units to lower case so we can match case insensetive
    case unitstr.toLower()[0]:#Match just the first char so that mb and mib work
    of 'b':
        multiplier = 1
    
    of 'k':
        multiplier = 1024

    of 'm':
        multiplier = 1024 ** 2

    of 'g':
        multiplier = 1024 ** 3

    of 't':
        multiplier = 1024 ** 4

    of 'p':
        multiplier = 1024 ** 5

    of 'e':
        multiplier = 1024 ** 6

    of 'z':
        multiplier = 1024 ** 7

    of 'y':
        multiplier = 1024 ** 8

    of 'r':
        multiplier = 1024 ** 9

    of 'q':
        multiplier = 1024 ** 10

    else:
        discard   

    #If we are returning bits then multiply by 8 to get the result in bits
    when retBits:
        multiplier * 8

    return multiplier * parseInt(intstr)