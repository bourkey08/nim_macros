#Implements functions for working with time and time stamps
import std/[macros, times]

#Implement functions for returning the current time in a variety of formats
proc time_s*(): uint64 {.inline.} =
    return uint64(epochTime())

proc time_ms*(): uint64 {.inline.} =
    return uint64(epochTime() * 1_000)

proc time_us*(): uint64 {.inline.} =
    return uint64(epochTime() * 1_000_000)
