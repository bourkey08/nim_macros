#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                    Implements compile time loop expansion macros
#------------------------------------------------------------------------------------------------------------------------------------------------------


macro sFor(params: untyped, body: untyped): untyped =
    #Split up the params into the identifier and the range
    if params.kind != nnkInfix:
        raise newException(ValueError, "First argument to staticFor must be an infix expression of the form 'ident in range'")

    if params[0].kind != nnkIdent or $params[0] != "in":
        raise newException(ValueError, "First argument to staticFor must be an infix expression of the form 'ident in range'")

    if params.len < 3:
        raise newException(ValueError, "First argument to staticFor must be an infix expression of the form 'ident in range'")

    let ident = params[1]
    let rng = params[2]

    #Define the list of ast nodes to generate for each iteration of the loop
    result = newStmtList()

    var startRng = rng[1].intVal
    var endRng = rng[2].intVal

    case $rng[0]:
    of "..":
        discard
    of "..<":
        endRng = endRng - 1

    for i in 0..endRng:
        result.add quote do:
            block:
                let `ident` = `i`
                `body`

#Takes a look in the format expandLoop ident, {seq of values} and applys the body to each value in the seq
macro expandLoop(v: untyped, rng: untyped, body: untyped): untyped =
    result = newStmtList()

    if v.kind != nnkIdent:
        raise newException(ValueError, "First argument to expandLoop must be an identifier")

    if rng.kind != nnkCurly:
        raise newException(ValueError, "Second argument to expandLoop must be a bracket expression")
    
    for child in rng:
        result.add quote do:
            block:
                var `v` = `child`
                `body`
                `child` = `v`

sFor i in 0..<10:
    echo i*2

quit()