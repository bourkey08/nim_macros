#------------------------------------------------------------------------------------------------------------------------------------------------------
#                            Defines macros that implement parallel loops that assign to a global thread pool created at launch
#------------------------------------------------------------------------------------------------------------------------------------------------------
#Used to get the number of CPU cores for thread pool sizing
import std/[cpuinfo, macrocache, macros, atomics, locks]

#Define a type for the thread pool that jobs are allocated to from parallel macros
type BThreadPool = ref object
    tCount: int
    threads: seq[Thread[tuple[pool: BThreadPool, idx: int]]]
    chann: Channel[tuple[f: proc(index: int), i: int]]

#Define globally scoped variable for the thread pool instance and a flag to ensure init code is only generated once
var poolInitCodeGenerated {.compileTime.} = false
const bPoolFuncCounter = CacheCounter"bPoolFuncCounter"#Used to allocate unique variable names
var bThreadPoolGInst: BThreadPool

#Constructor for the thread pool
proc newBThreadPool(tCount: int): BThreadPool =
    var tPool = BThreadPool(tCount: tCount)
    tPool.threads = newSeq[Thread[tuple[pool: BThreadPool, idx: int]]](tCount)
    tPool.chann.open()
    return tPool

#Method that is the entry point for each thread in the pool
proc threadPoolMethod(args: tuple[pool: BThreadPool, idx: int]) {.thread.} =
    while true:
        when defined(DEBUG_BTHREADPOOL):
            echo "Thread " & $args.idx & " waiting for job..."

        let (job, index) = args.pool.chann.recv()

        when defined(DEBUG_BTHREADPOOL):
            echo "Thread " & $args.idx & " got job, executing..."

        gcSafe:
            job(index)

#Macro for initilizing the pool used for parallel macros with a number of threads that matches the number of CPU cores
macro initBPool(count: static int = 0): untyped =
    let poolName = newIdentNode("bThreadPoolGInst")

    when not poolInitCodeGenerated:
        poolInitCodeGenerated = true
    else:
        return newStmtList() #No code generated on subsequent calls

    result = quote do:
        #If the thread pool is required make sure we have a suitable memory manager
        when not defined(gcOrc) and not declared(gcArc) and not defined(gcAtomicArc):
            raise newException(ValueError, "parallelUtils.nim requires orc or arc memory manager to be enabled")

        #This needs to be at runtime so we get the correct number of processors
        let tCount = tern(`count` == 0, cpuinfo.countProcessors(), `count`)

        #Create a globally scoped thread pool
        `poolName` = newBThreadPool(tCount)

        for i in 0..<tCount:
            createThread(`poolName`.threads[i], threadPoolMethod, (`poolName`, i))

macro pFor(i: untyped, rnge: untyped, body: untyped): untyped =
    bPoolFuncCounter.inc()
    result = newStmtList()

    # Parse the range expression (e.g., 0..12)
    var start, finish: int
    var loopKind: int = 0

    #Assumes range is of the form a..b
    if rnge[1].kind == nnkIntLit and rnge[2].kind == nnkIntLit:
        #Both are int literals
        start = rnge[1].intVal.int
        finish = rnge[2].intVal.int
        loopKind = tern($rnge[0].repr == "..", 0, 1)
    else:
        raise newException(ValueError, "parallelUtils.nim pFor macro only supports int literal ranges at compile time")

    #Ensure the thread pool is initialized
    result.add quote do:
        initBPool()

    #Intialize counter and cond needed to track job completion efficently
    let poolName = newIdentNode("bThreadPoolGInst")
    let jobDoneCounter = newIdentNode("jobDoneCounter_" & $bPoolFuncCounter.value)
    let jobDoneLock = newIdentNode("jobDoneLock_" & $bPoolFuncCounter.value)
    let jobDoneCond = newIdentNode("jobDoneCond_" & $bPoolFuncCounter.value)    

    #Create a counter to track the number of threads/jobs done
    result.add quote do:
        var `jobDoneLock`: Lock
        `jobDoneLock`.initLock()
        var `jobDoneCond`: Cond
        `jobDoneCond`.initCond()

        var `jobDoneCounter`: Atomic[int]
        `jobDoneCounter`.store(0)

    #Add a method for the body of the loop
    var bodyIndent = newIdentNode("body_" & $bPoolFuncCounter.value)
    var bodyArgIdent = newIdentNode("index")

    result.add quote do:
        proc `bodyIndent`(`bodyArgIdent`: int) =
            let `i` = `bodyArgIdent`
            gcSafe:
                `body`
                if `loopKind` == 0:
                    if `jobDoneCounter`.fetchAdd(1) >= (`finish` - `start`):  #Last job to finish
                        `jobDoneCond`.broadcast()
                else:
                    if `jobDoneCounter`.fetchAdd(1) + 1 >= (`finish` - `start`):  #Last job to finish
                        `jobDoneCond`.broadcast()
    
    #Now generate the loop code    
    if loopKind == 0:
        for idx in `start`..`finish`:
            result.add quote do:
                var jobEntry: tuple[f: proc(index: int), i: int] = (`bodyIndent`, `idx`)
                `poolName`.chann.send(jobEntry)
    else:
        for idx in `start`..<`finish`:
            result.add quote do:
                var jobEntry: tuple[f: proc(index: int), i: int] = (`bodyIndent`, `idx`)
                `poolName`.chann.send(jobEntry)
    

    #Finally wait for all jobs to complete
    result.add quote do:
        `jobDoneCond`.wait(`jobDoneLock`)

        #Loop is done, free the lock and cond
        `jobDoneLock`.deinitLock()
        `jobDoneCond`.deinitCond()

macro pMap(data: untyped, body: untyped) : untyped =
    bPoolFuncCounter.inc()
    result = newStmtList()

    #Ensure the thread pool is initialized
    result.add quote do:
        initBPool()

    if data[0].kind != nnkIdent or data[0].strVal != "in":
        raise newException(ValueError, "parallelUtils.nim pMap macro expects 'entry in data' syntax")

    #Split out the loop variables and data sequence
    let loopVar = newIdentNode($data[1])
    let dataSeq = data[2]

    #Intialize counter and cond needed to track job completion efficently
    let poolName = newIdentNode("bThreadPoolGInst")
    let jobDoneCounter = newIdentNode("jobDoneCounter_" & $bPoolFuncCounter.value)
    let jobDoneLock = newIdentNode("jobDoneLock_" & $bPoolFuncCounter.value)
    let jobDoneCond = newIdentNode("jobDoneCond_" & $bPoolFuncCounter.value)    

    #Create a counter to track the number of threads/jobs done
    result.add quote do:
        var `jobDoneLock`: Lock
        `jobDoneLock`.initLock()
        var `jobDoneCond`: Cond
        `jobDoneCond`.initCond()

        var `jobDoneCounter`: Atomic[int]
        `jobDoneCounter`.store(0)

    #Add a method for the body of the loop
    var bodyIndent = newIdentNode("body_" & $bPoolFuncCounter.value)
    var bodyArgIdent = newIdentNode("index")
    var outDataIdent = newIdentNode("outputData_" & $bPoolFuncCounter.value)

    #Generate the setup code for the output data
    result.add quote do:
        #Define the loop variable with the correct type and the output data seq
        var `loopVar`: typeof(`dataSeq`[0])
        var `outDataIdent` = newSeq[type(`body`)](`dataSeq`.len)

    #Add the body method that is called by each loop job
    result.add quote do:
        proc `bodyIndent`(`bodyArgIdent`: int) : auto =
            let `loopVar` = `dataSeq`[`bodyArgIdent`]
            gcSafe:
                let resp = `body`
                `outDataIdent`[`bodyArgIdent`] = resp
                if `jobDoneCounter`.fetchAdd(1) >= (`dataSeq`.len - 1):  #Last job to finish
                    `jobDoneCond`.broadcast()

    #Now generate the code to dispatch jobs for each entry in the data seq
    result.add quote do:
        for idx in 0..<`dataSeq`.len:
            var jobEntry: tuple[f: proc(index: int), i: int] = (`bodyIndent`, idx)
            `poolName`.chann.send(jobEntry)

        #Finally wait for all jobs to complete
        `jobDoneCond`.wait(`jobDoneLock`)

        #Loop is done, free the lock and cond
        `jobDoneLock`.deinitLock()
        `jobDoneCond`.deinitCond()   

        #Return the output data seq
        `outDataIdent`

#Implements a parallel loop that does not have a return
macro pExp(v: untyped, rnge: untyped, body: untyped): untyped =
    bPoolFuncCounter.inc()
    bPoolFuncCounter.inc()
    result = newStmtList()

    # Parse the range expression (e.g., 0..12)
    var start, finish: int
    var loopKind: int = 0

    #Assumes range is of the form a..b
    if rnge[1].kind == nnkIntLit and rnge[2].kind == nnkIntLit:
        #Both are int literals
        start = rnge[1].intVal.int
        finish = rnge[2].intVal.int
        loopKind = tern($rnge[0].repr == "..", 0, 1)
    else:
        raise newException(ValueError, "parallelUtils.nim pFor macro only supports int literal ranges at compile time")

    #Ensure the thread pool is initialized
    result.add quote do:
        initBPool()

    #Intialize counter and cond needed to track job completion efficently
    let poolName = newIdentNode("bThreadPoolGInst")
    let jobDoneCounter = newIdentNode("jobDoneCounter_" & $bPoolFuncCounter.value)
    let jobDoneLock = newIdentNode("jobDoneLock_" & $bPoolFuncCounter.value)
    let jobDoneCond = newIdentNode("jobDoneCond_" & $bPoolFuncCounter.value)    

    #Create a counter to track the number of threads/jobs done
    result.add quote do:
        var `jobDoneLock`: Lock
        `jobDoneLock`.initLock()
        var `jobDoneCond`: Cond
        `jobDoneCond`.initCond()

        var `jobDoneCounter`: Atomic[int]
        `jobDoneCounter`.store(0)

    #Add a method for the body of the loop
    var bodyIndent = newIdentNode("body_" & $bPoolFuncCounter.value)

    result.add quote do:
        proc `bodyIndent`(`v`: int) =
            gcSafe:
                `body`
                if `loopKind` == 0:
                    if `jobDoneCounter`.fetchAdd(1) >= (`finish` - `start`):  #Last job to finish
                        `jobDoneCond`.broadcast()
                else:
                    if `jobDoneCounter`.fetchAdd(1) + 1 >= (`finish` - `start`):  #Last job to finish
                        `jobDoneCond`.broadcast()
    
    #Now generate the loop code  
    if loopKind == 0:
        for idx in `start`..`finish`:
            result.add quote do:
                var jobEntry: tuple[f: proc(index: int), i: int] = (`bodyIndent`, `idx`)
                `poolName`.chann.send(jobEntry)
    else:
        for idx in `start`..<`finish`:
            result.add quote do:
                var jobEntry: tuple[f: proc(index: int), i: int] = (`bodyIndent`, `idx`)
                `poolName`.chann.send(jobEntry)

    #Finally wait for all jobs to complete
    result.add quote do:
        `jobDoneCond`.wait(`jobDoneLock`)

        #Loop is done, free the lock and cond
        `jobDoneLock`.deinitLock()
        `jobDoneCond`.deinitCond()
        
#Macros for transforming sync calls into async calls via the thread pool
#Implements a macro that allows a block of code to be run in a thread and awaited using a future
#This is used to allow async interfaces to be used in threaded code that is not async aware
#Note: This should not be used in a loop as it will cause issues with multiple completions of a single future
when defined(Future):
    macro inThread(body: untyped): Future[void] =
        bPoolFuncCounter.inc()
        result = newStmtList()

        #Ensure the thread pool is initialized
        result.add quote do:
            initBPool()

        #Define identifiers used in the generated code to ensure unique names for each macro call and avoid name collisions
        let poolName = newIdentNode("bThreadPoolGInst")
        let bodyIndent = newIdentNode("body_" & $bPoolFuncCounter.value)
        let wrapper = newIdentNode("wrapper_" & $bPoolFuncCounter.value)        

        #Build the body method that is called by the thread pool
        result.add quote do:
            var respFut: Future[void] = newFuture[void]()

            proc `bodyIndent`(index: int) =
                gcSafe:
                    `body`

                respFut.complete()

            #Now dispatch the job to the thread pool
            let idx: int = 0
            var jobEntry: tuple[f: proc(index: int), i: int] = (`bodyIndent`, idx)
            `poolName`.chann.send(jobEntry)

            #Return the future to the caller
            proc `wrapper`(baseFut: Future[void]): Future[void] {.async.} =
                while true:       
                    if baseFut.finished:
                        break
                    else:
                        await sleepAsync(1)

            `wrapper`(respFut)
