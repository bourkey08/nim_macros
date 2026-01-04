#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                    Misc debug tools and benchmarking utilities
#------------------------------------------------------------------------------------------------------------------------------------------------------
macro typeSize(v: untyped): untyped =
    result = newStmtList()

    let typeName = newLit(v.repr)

    #Check if the type is a reference type    
    result.add quote do:
        echo `typeName` & ": " & $(psizeof(`v`))

macro typeSizes(types: varargs[untyped]): untyped = 
    result = newStmtList()

    result.add quote do:
        echo "\nType Sizes: "

    for t in types:
        result.add quote do:
            typeSize(`t`)

    result.add quote do:
        echo ""
    
macro runBenchmark(count: static int64, desc: static string, body: untyped): untyped =
    result = newStmtList()

    result.add quote do:
        let start = getMonoTime()
        for i in 0..<`count`:
            `body`
            
        let runtime = (getMonoTime() - start)
        var runtimeUnits = "ns"
        var runtimeInt = inNanoseconds(runtime)

        while (runtimeInt.float64 / `count`.float64 > 500):
            case runtimeUnits:
            of "ns":
                runtimeInt = inMicroseconds(runtime)
                runtimeUnits = "us"
            of "us":
                runtimeInt = inMilliseconds(runtime)
                runtimeUnits = "ms"
            of "ms":
                runtimeInt = inSeconds(runtime)
                runtimeUnits = "s"
            else:
                break

        echo `desc` & ": " & $(runtimeInt.float64 / `count`.float64) & " " & runtimeUnits & " per operation\n"
