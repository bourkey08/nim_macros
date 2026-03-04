import macros, strutils

#Takes a string containing a value with a unit and converts this to bytes/bits
func parseBinaryUnits(text: string, retBits: static[bool]=false): int {.inline.} =
    #Define 2 sequences we will add all characters to based on if they are numbers
    var intchars: seq[char] = @[]
    var unitchars: seq[char] = @[]

    if text == "" or text == "0":
        return 0

    var firstDot = false
    for i in text:
        if i.isdigit:
            intchars.add i

        elif i == '.':
            if firstDot:
                raise newException(ValueError, "Invalid format for binary unit value, multiple decimal points found")
            else:
                firstDot = true
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

    #If the value is a float then case everything to float and then back to it after the multiplication to allow for fractional values
    if firstDot:
        return int(multiplier.float64 * parseFloat(intstr))
    else:
        return multiplier * parseInt(intstr)

#Takes a value in bytes and returns it formatted as a string with the appropriate unit
func formatBinaryUnits(value: auto, places: int = 2): string {.inline.} =
    if value == 0:
        return "0 B"

    #First lets work out the units to use and divide out the value as we go
    var unit: string = "B"
    var val= float64(value)

    while val >= 1024:
        val /= 1024
        case unit[0]:
        of 'B':
            unit = "KB"
        of 'K':
            unit = "MB"
        of 'M':
            unit = "GB"
        of 'G':
            unit = "TB"
        of 'T':
            unit = "PB"
        of 'P':
            unit = "EB"
        of 'E':
            unit = "ZB"
        of 'Z':
            unit = "YB"
        of 'Y':
            unit = "RB"
        of 'R':
            unit = "QB"
        else:
            break

    #Now format the value to the required number of decimal places
    var resp = $val
    let split = resp.split(".")
    if places > 0 and split.len > 1:
        resp = split[0] & "." & split[1][0..<min(places, split[1].len)]
    else:
        resp = split[0]
    #And return the value with the unit
    return resp & " " & unit

#Add an alias to make it cleaner when embedding binary units
template bUnit(val: string): untyped = 
    parseBinaryUnits(val)