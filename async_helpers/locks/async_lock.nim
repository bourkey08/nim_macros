#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                    Implements locks for parallel async IO operations
#------------------------------------------------------------------------------------------------------------------------------------------------------
import std/[macros, asyncdispatch]

include "./async_lock_single.nim"
include "./async_lock_dual.nim"
include "./async_lock_tiered.nim"
include "./async_lock_sugar.nim"