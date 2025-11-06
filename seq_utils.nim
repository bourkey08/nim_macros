#Implements macros for working with sequences and arrays
import macros

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