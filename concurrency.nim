import std/[locks, asyncdispatch, compilesettings]
from "./utils.nim" import psizeof

const FALLBACK_SLEEP_DELAY = 0.01#10us The delay between checking for changes when using the fallback method for async awaits between threads

#Enable experimental features that are used
{.experimental: "codeReordering".}


const gcUsed = querySetting(gc)
when gcUsed == "arc" or gcUsed == "orc" or gcUsed == "none" or gcUsed == "atomicArc":
    const fallBackThreading = false
else:
    const fallBackThreading = true

proc keepAlive() {.async.} = 
    while true:
        await sleepAsync(1000)

#When using a memory mangment method that has a shared heap then we can use a ref object
when fallBackThreading == false:
    type AsyncCond* = ref object
        event: Future[void]
        lock: Lock
        condLock: Lock
        cond: Cond

    proc newAsyncCond*(): AsyncCond =
        var resp = AsyncCond(
            event: newFuture[void]()
        )

        resp.lock.initLock()
        resp.condLock.initLock()
        resp.cond.initCond()

        return resp

else:#Otherwise fall back to using a pointer object to get around the gc        
    type AsyncCond* = ptr object
        event: Future[void]
        lock: Lock
        condLock: Lock
        cond: Cond
        counter: uint64

    proc newAsyncCond*(): AsyncCond =
        var resp: AsyncCond = cast[AsyncCond](allocShared(psizeof(AsyncCond) + 1024))
        resp.event = newFuture[void]()
        resp.counter = uint64 0

        resp.lock.initLock()
        resp.condLock.initLock()
        resp.cond.initCond()

        asyncCheck keepAlive()

        return resp

proc set*(self: AsyncCond) =
    #Get the locks for both sync and async operations
    self.lock.acquire()
    self.condLock.acquire()

    #Replace the future used for async operations
    
    self.cond.signal()

    when fallBackThreading:
        self.counter += 1
    else:
        #Complete the future to signal that the condition has triggered
        self.event.complete()

        #Create a new future for the next async operation
        self.event = newFuture[void]()

    #Release the locks
    self.condLock.release()
    self.lock.release()

proc wait*(self: AsyncCond) {.async.} =
    when fallBackThreading == true:
        var counter = self.counter

        while true:
            self.lock.acquire()
            var value = self.counter

            if value != counter:
                self.lock.release()
                break
            else:
                self.lock.release()
                await sleepAsync(FALLBACK_SLEEP_DELAY)

    else:
        await self.event
        self.lock.acquire()

        #Ensure that a new future was not added in the time between the await and the lock being acquired and if there was then wake up anything waiting on it
        if not self.event.finished:
            self.event.complete()

        #Now replace the future to ensure subsequent waits are not resolved by the same set
        self.event = newFuture[void]()

        self.lock.release()

proc waitSync*(self: AsyncCond) =
    #Await the syncronous condition
    self.cond.wait(self.condLock)
