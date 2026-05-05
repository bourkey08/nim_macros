#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                Defines Misc helper functions for async operations/Futures
#------------------------------------------------------------------------------------------------------------------------------------------------------
import std/[asyncdispatch]

#Include the child async librarys
include "./async_trigger.nim"
include "./async_limiter.nim"

#Implements functionality for launching subprocesses and handling their output asynchronously
include "./subprocess/subprocess.nim"

template isAsync(): untyped = 
    when compiles(await sleepAsync(0)):
        true
    else:
        false