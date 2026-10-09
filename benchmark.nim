#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                    Implements macros to assist in benchmarking code 
#------------------------------------------------------------------------------------------------------------------------------------------------------
import std/[macros, macrocache, times, monotimes]

#Include the format number function to allow for better formatting of the output
include "./num_utils.nim"

#Toggle to allow benchmarks to be enabled/disabled
const ENABLE_BENCHMARKS {.booldefine: "bench".} = false
const BenchmarkCounter = CacheCounter"BenchmarkCounter"

#[ Takes a start and finish time and returns a string with the time difference in the most appropriate units
    - start: The start time as a MonoTime
    - stop: The finish time as a MonoTime
    - d: The minimum value to display in a unit before going down to the next smaller unit, defaults to 1
    - decimals: The number of decimal places to display, defaults to 2
    - count: The number of iterations the benchmark was run for, defaults to 1
]#
func autoUnits(start: MonoTime, stop: MonoTime, d: SomeInteger = 1, decimals: static int = 2, count: SomeInteger = 1): string =
    let cutOff = d * 1000#As we are using the next unit down to get the decimals the cutoff is actually 1000x the d value

    let msTime = inMilliseconds(stop - start) div count.int
    if msTime < cutOff:
        let usTime = inMicroseconds(stop - start) div count.int
        if usTime < cutOff:
            let nsTime = inNanoseconds(stop - start) div count.int
            if nsTime < cutOff:
                return formatNumber(nsTime.float64, true, decimals.uint64) & " ns"
            else:
                return formatNumber(nsTime.float64 / 1000, true, decimals.uint64) & " us"      
        else:
            return formatNumber(usTime.float64 / 1000, true, decimals.uint64) & " ms"    
    else:
        return formatNumber(msTime.float64 / 1000, true, decimals.uint64) & " s"

#Prevent conflicts with any existing benchmarks
when not defined(benchmark):
    macro benchmark*(title: string, iters: int, code: untyped): untyped =

        #First find the setup section if there is one
        var setup = newStmtList()
        var body = newStmtList()#Everything except the setup
        
        #Iterate over the code to find any call to the setup function then extract that code
        var setupFound = false
        for i in 0..<code.len:
            if code[i].kind == nnkCall:
                if $code[i][0] == "setup":
                    for frame in code[i][1..^1]:
                        setup.add quote do:
                            `frame`

                    #Now assemble the body
                    for j in 0..<code.len:
                        if j != i:
                            let frame = code[j]
                            body.add quote do:
                                `frame`

                    setupFound = true
                    break

        #If there is no setup code just copy the whole code block as the body
        if not setupFound:
            body.add quote do:
                `code`

        #Now assemble the benchmarking code
        result = newStmtList()

        when ENABLE_BENCHMARKS:
            #Add the setup code before everything else
            result.add quote do:
                `setup`

            result.add quote do:
                let s1 = getMonoTime()

                for i in 0..<`iters`:
                    `body`

                #Now calculate the runtime and averages
                let s2 = getMonoTime()

                echo "Running Benchmark: [" & `title` & "]"

                #Get the string and align the units for the total and average times
                var totalStr = autoUnits(s1, s2, 1)
                var avgStr = autoUnits(s1, s2, 1, count=`iters`)
                while (avgStr.len + 3) != totalStr.len:
                    if (avgStr.len + 3) < totalStr.len:
                        avgStr = " " & avgStr
                    else:
                        totalStr = " " & totalStr

                echo "    Total: ", totalStr
                echo "    Avg Per: ", avgStr & "\n"

            #Finally wrap the whole thing in a block to avoid name conflicts
            result = quote do:
                block:
                    `result`

    #Wrapper to allow benchmarks without titles
    macro benchmark*(iters: int, body: untyped): untyped =
        template miscBench(title: string, iters: int, body: untyped): untyped =
            benchmark(`title`, `iters`, `body`)

        BenchmarkCounter.inc()

        let benchIdx = $BenchmarkCounter.value()

        result = quote do:
            miscBench(`benchIdx`, `iters`, `body`)            
                
#Defines a simple macro for timing a block of code without affecting its function or scope
#Arguments (all optional):
#   title: A string to identify the benchmark in the output, defaults to "Benchmark"
#   iters: The number of iterations to run the code block for, defaults to 1
#   units: The units to display the results in, can be "m|ms" for milliseconds or "u|us" for microseconds, defaults to "ms"

macro timeIt*(body: untyped): untyped =
    result = newStmtList()

    result.add quote do:
        let start = getMonoTime()

        `body`

        let finish = getMonoTime()
        echo "Benchmark: " & autoUnits(start, finish, 1)