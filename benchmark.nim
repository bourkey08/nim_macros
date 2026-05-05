#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                    Implements macros to assist in benchmarking code 
#------------------------------------------------------------------------------------------------------------------------------------------------------
import std/[macrocache, times, monotimes]

#Toggle to allow benchmarks to be enabled/disabled
const ENABLE_BENCHMARKS {.booldefine: "bench".} = false
const BenchmarkCounter = CacheCounter"BenchmarkCounter"

#Prevent conflicts with any existing benchmarks
when not defined(benchmark):
    macro benchmark(title: string, iters: int, code: untyped): untyped =

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
                let runtime = inMicroseconds(getMonoTime() - s1)

                echo "Running Benchmark: [" & `title` & "]"

                echo "    Total: ", runtime.float64 / 1000.0, " ms"
                echo "    Avg Per: ", runtime.float64 / `iters`.float64, " us\n"

            #Finally wrap the whole thing in a block to avoid name conflicts
            result = quote do:
                block:
                    `result`

    #Wrapper to allow benchmarks without titles
    macro benchmark(iters: int, body: untyped): untyped =
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

macro timeIt(body: untyped): untyped =
    result = newStmtList()

    result.add quote do:
        let start = getMonoTime()

        `body`

        let finish = getMonoTime()

        let runtime = inMilliseconds(finish - start)

        if runtime < 10:
            let rtUs = inMicroseconds(finish - start)
            echo "Benchmark: " &  $rtUs & " us"
        else:
            let rtMs = runtime.float64

            echo "Benchmark: " &  $rtMs & " ms"