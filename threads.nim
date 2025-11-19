#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                    Implements a thread pool as well as misc utilities for simplified threading
#------------------------------------------------------------------------------------------------------------------------------------------------------
import std/[macros, locks]

{.experimental: "codeReordering".}

#Type for the global thread pool created by initBlibTPool
type BLIBThreadPool[C: static int] = ptr object
    len: int
    threads: array[C, Thread[BLIBThreadPool[C]]]
    tasks: seq[proc()]
    lock: Lock
    taskAvailable: Cond
    shutdown: bool

proc BlibTPoolProc(pool: BLIBThreadPool) {.thread.} =
    while pool.shutdown == false:
        var task: proc() = nil

        #Acquire the lock to access the task queue
        acquire(pool.lock)

        #Wait until there is a task available or we are shutting down
        while pool.tasks.len == 0 and not pool.shutdown:
            wait(pool.taskAvailable, pool.lock)

        #If we are shutting down, exit the thread
        if pool.shutdown:
            release(pool.lock)
            break

        #Get the next task from the queue
        if pool.tasks.len > 0:
            task = pool.tasks[0]
            pool.tasks.delete(0)

        release(pool.lock)

        #Execute the task outside of the lock
        if task != nil: 
            {.cast(gcsafe).}:
                task()

#Called to initialize the global thread pool for this library with the target number of threads
macro initBlibTPool(count: static int = 4): untyped =
    var tPool = newIdentNode("GlobalBLIBThreadPool")

    result = quote do:        
        var `tPool` {.global.}: BLIBThreadPool[`count`] = cast[BLIBThreadPool[`count`]](allocShared(psizeof(BLIBThreadPool[`count`])))
        `tPool`.len = `count`
        `tPool`.tasks = @[]
        initLock(`tPool`.lock)
        initCond(`tPool`.taskAvailable)
        `tPool`.shutdown = false

        #Now spawn the threads
        for i in 0..<`tPool`.len:
            createThread(`tPool`.threads[i], BlibTPoolProc, `tPool`)

when defined(blibThreadPool):
    const BLIB_THREAD_POOL_SIZE {.intdefine: "blibThreadPoolSize"} = 4
    initBlibTPool(BLIB_THREAD_POOL_SIZE)

    proc shutdownBlibTPool(pool: BLIBThreadPool) =
        ## Shuts down the thread pool and waits for all threads to finish.
        acquire(pool.lock)
        pool.shutdown = true
        broadcast(pool.taskAvailable)
        release(pool.lock)

        #Wait for all threads to finish
        for i in 0..<pool.len:
            joinThread(pool.threads[i])

        #Free the lock and condition variable
        pool.lock.destroy()
        pool.taskAvailable.destroy()

    #Submits a task to the thread pool to be executed
    proc submitToBlibTPool(task: proc()) =
        var pool = GlobalBLIBThreadPool
        acquire(pool.lock)
        pool.tasks.add(task)
        signal(pool.taskAvailable)
        release(pool.lock)
