#Implements functions for working with time and time stamps
import std/[macros, times, strutils]

#Implement functions for returning the current time in a variety of formats
proc time_s*(): uint64 {.inline.} =
    return uint64(epochTime())

proc time_ms*(): uint64 {.inline.} =
    return uint64(epochTime() * 1_000)

proc time_us*(): uint64 {.inline.} =
    return uint64(epochTime() * 1_000_000)

#Takes a duration string and converts it to the target unit (d, h, m, s, ms, us, ns)
func parseDuration*(duration: string, unit: string = "s"): int {.inline.} =
    #Define a functon that can be used to convert units to a common format (eg h and hr is the same)
    func aliasUnits(unit: string): string {.inline.} =
        case unit.toLower():
        of "d", "day":
            return "d"
        of "h", "hr", "hour":
            return "h"
        of "m", "min", "minute":
            return "m"
        of "s", "sec", "second":
            return "s"
        of "ms", "milli", "millisecond":
            return "ms"
        of "us", "micro", "microsecond":
            return "us"
        of "ns", "nano", "nanosecond":
            return "ns"
        else:
            raise newException(ValueError, "Invalid unit string");

    var resp: int = 0

    #Now split the duration string into the number and the unit
    var num: string
    var unitstr: string

    for i in 0..<duration.len:
        if duration[i].isdigit:
            num.add duration[i]
        else:
            unitstr = duration[i..<duration.len]
            break

    #Now convert the number to an int
    let numint = parseInt(num)

    #Now calculate a multiplier based on the source unit and the target unit
    #The float multiplier is only used for conversions that are not whole numbers in order to avoid rounding errors when converting integer values
    var multi = 0;
    var multiFloat: float64 = 0.0

    case aliasUnits(unitstr):
    of "d":
        case aliasUnits(unit):
        of "d":
            multi = 1
        of "h":
            multi = 24
        of "m":
            multi = 24 * 60
        of "s":
            multi = 24 * 60 * 60
        of "ms":
            multi = 24 * 60 * 60 * 1_000
        of "us":
            multi = 24 * 60 * 60 * 1_000_000
        of "ns":
            multi = 24 * 60 * 60 * 1_000_000_000 
    of "h":
        case aliasUnits(unit):
        of "d":
            multiFloat = 1 / 24
        of "h":
            multi = 1
        of "m":
            multi = 60
        of "s":
            multi = 60 * 60
        of "ms":
            multi = 60 * 60 * 1_000
        of "us":
            multi = 60 * 60 * 1_000_000
        of "ns":
            multi = 60 * 60 * 1_000_000_000
    of "m":
        case aliasUnits(unit):
        of "d":
            multiFloat = 1 / (24 * 60)
        of "h":
            multiFloat = 1 / 60
        of "m":
            multi = 1
        of "s":
            multi = 60
        of "ms":
            multi = 60 * 1_000
        of "us":
            multi = 60 * 1_000_000
        of "ns":
            multi = 60 * 1_000_000_000
    of "s":
        case aliasUnits(unit):
        of "d":
            multiFloat = 1 / (24 * 60 * 60)
        of "h":
            multiFloat = 1 / (60 * 60)
        of "m":
            multiFloat = 1 / 60
        of "s":
            multi = 1
        of "ms":
            multi = 1_000
        of "us":
            multi = 1_000_000
        of "ns":
            multi = 1_000_000_000
    of "ms":
        case aliasUnits(unit):
        of "d":
            multiFloat = 1 / (24 * 60 * 60 * 1_000)
        of "h":
            multiFloat = 1 / (60 * 60 * 1_000)
        of "m":
            multiFloat = 1 / (60 * 1_000)
        of "s":
            multiFloat = 1 / 1_000
        of "ms":
            multi = 1
        of "us":
            multi = 1_000
        of "ns":
            multi = 1_000_000
    of "us":
        case aliasUnits(unit):
        of "d":
            multiFloat = 1 / (24 * 60 * 60 * 1_000_000)
        of "h":
            multiFloat = 1 / (60 * 60 * 1_000_000)
        of "m":
            multiFloat = 1 / (60 * 1_000_000)
        of "s":
            multiFloat = 1 / 1_000_000
        of "ms":
            multiFloat = 1 / 1_000
        of "us":
            multi = 1
        of "ns":
            multi = 1_000
    of "ns":
        case aliasUnits(unit):
        of "d":
            multiFloat = 1 / (24 * 60 * 60 * 1_000_000_000)
        of "h":
            multiFloat = 1 / (60 * 60 * 1_000_000_000)
        of "m":
            multiFloat = 1 / (60 * 1_000_000_000)
        of "s":
            multiFloat = 1 / 1_000_000_000
        of "ms":
            multiFloat = 1 / 1_000_000
        of "us":
            multiFloat = 1 / 1_000
        of "ns":
            multi = 1
    else:
        raise newException(ValueError, "Invalid unit string");

    #Now calculate the response using which ever multiplier was set
    if multi == 0:
        resp = int(float64(numint) * multiFloat)
    else:
        resp = numint * multi

    return resp

#Takes a time string and converts it to units since midnight
#Valid options for units are s, m, h
func parseTime*(val: string, unit: string = "s"): int {.inline.} =
    #First convert the val to an int with seconds since midnight
    var seconds = 0

    #Now split the time string into the various parts (H:M:S or H:M are acceted)
    var parts = val.split(":")

    if parts.len == 2:
        seconds = (parseInt(parts[0]) * 3600) + (parseInt(parts[1]) * 60)

    elif parts.len == 3:
        seconds = (parseInt(parts[0]) * 3600) + (parseInt(parts[1]) * 60) + parseInt(parts[2])
        
    else:
        raise newException(ValueError, "Invalid time string");

    #Now convert the seconds to the target unit
    case unit.toLower():
    of "s":
        return seconds
    of "m":
        return seconds div 60
    of "h":
        return seconds div 3600
    else:
        raise newException(ValueError, "Invalid unit string");

func formatDuration*(duration: float|float64|float32|int|int64|int32|uint64|uint32|uint, unit: string = "s"): string  =
    #First convert the duration to seconds
    var seconds = 0
    case unit.toLower():
    of "ms":
        seconds = int(float64(duration) / 1_000)
    of "s":
        seconds = int(duration)
    of "m":
        seconds = int(duration) * 60
    of "h":
        seconds = int(duration) * 3600
    of "d":
        seconds = int(duration) * 86400
    else:
        raise newException(ValueError, "Invalid unit string");

    #Now format the seconds as a string
    var parts: seq[string] = @[]

    for s in [86400, 3600, 60, 1]:
        if seconds > s:               
            var val = seconds div s
            seconds = seconds mod s
            var strVal = $val

            if s != 86400:#For the 3 time parts ensure its always 2 digits
                if strVal.len < 2:
                    strVal = "0" & strVal

            parts.add(strVal)

    #Now join the parts into a single string
    if parts.len == 4:
        if parts[0] == "1":
            return parts[0] & " day, " & parts[1] & ":" & parts[2] & ":" & parts[3]
        else:
            return parts[0] & " days, " & parts[1] & ":" & parts[2] & ":" & parts[3]
    elif parts.len == 3:
        return parts[0] & ":" & parts[1] & ":" & parts[2]
    elif parts.len == 2:
        return parts[0] & ":" & parts[1]
    elif parts.len == 1:
        return parts[0]
    else:
        return "0"#Return 0 to avoid crashing the program 
        