#Implements macros for working with sequences and arrays
import macros

{.experimental: "codeReordering".}
include "./seq_utils_threaded.nim"

#Macro to convert a slice of a sequence or array into an array of a fixed length
macro sliceToArray(seqExpr: untyped, start: int, length: static[int]): untyped =
    ## Macro to convert a slice of a sequence into an array of fixed length.
    var
        elems = newSeq[NimNode]()

    # Fill `elems` with elements accessed from the slice.
    for i in 0..length-1:
        let node = quote do: `seqExpr`[`start` + `i`]

        elems.add(node)

    # Construct the resulting array expression.
    result = quote do:
        `elems`   


#Macro to call a function with each element of an array or sequence
macro each[T](seq: openArray[T], fnc: untyped): untyped =
    result = quote do:
        for item in `seq`:
            `fnc`(item)


#Passes each value of a sequence or array to a function and returns a new sequence with the results
proc map[T](s: openArray[T], fnc: proc(x: T): T): seq[T] {.inline.} =
    ## Applies a function to each element of a sequence and returns a new sequence with the results.
    for i in 0..<s.len:
        result.add(fnc(s[i]))

#Only include this if async dispatch has been imported
when declared(await):
    #Works the same as each but for async functions
    macro aEach[T](s: openArray[T], fnc: proc(x: T): Future[void] {.async.}): untyped =
        result = quote do:
            var futs: seq[Future[void]] = @[]
            for item in `s`:
                futs.add(`fnc`(item))
            await all(futs)

    #Works the same as map but for async functions where they are each run in parallel
    macro aMap[T](s: openArray[T], fnc: proc(x: T): Future[T] {.async.}): untyped =
        result = quote do:
            var resp: seq[int] = @[]
            var futs: seq[Future[int]] = @[]#Used to store the futures while waiting for them to complete

            #Start all functions running in parallel
            for i in `s`:
                futs.add(`fnc`(i))

            #Wait for all functions to complete and fill out the resp sequence with the results
            for f in futs:
                resp.add(await f)

            resp