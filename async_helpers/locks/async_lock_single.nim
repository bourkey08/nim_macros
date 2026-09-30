#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                Implements the standard lock that allows for a single lock to be obtained at a time
#------------------------------------------------------------------------------------------------------------------------------------------------------

#------------------------------------------------------------------ Define the types -----------------------------------------------------------------
type AsyncLock = ref object
    held: bool = false    
    futIsSet: bool = false#If the future exists
    fut: Future[void]

#Object that is returned when a lock is acquire, this ensures that the lock cannot be released by logic that did not acquire it
type AsyncLockHold = object
    parent: AsyncLock
    held: bool = true

#------------------------------- Methods for the standard async lock -------------------------------
proc newAsyncLock(): AsyncLock =
    result = AsyncLock()

#Called to acquire the lock, waits for the lock to become available before returning
proc acquire(self: AsyncLock, timeout: auto = 0): Future[Opt[AsyncLockHold]] {.async.} =
    let tOut = timeout.uint64

    if tOut > 0:
        let start = time_ms()
        while true:
            if not self.held:
                self.held = true
                return som(AsyncLockHold(parent: self))
            
            else:
                #Calculate how long we can wait for the lock to be acquired before the timeout is reached
                let elapsed = time_ms() - start
                let remaining = tOut - elapsed
                
                if elapsed > tOut or remaining <= 0:
                    return non[AsyncLockHold]()

                #Wait until the lock is available or the timeout is reached
                if not self.futIsSet:
                    self.fut = newFuture[void]()
                    self.futIsSet = true
                await (self.fut or sleepAsync(remaining.int))
    else:
        while true:#Loop until the lock is acquired
            if not self.held:
                self.held = true
                return som(AsyncLockHold(parent: self))
            else:
                if not self.futIsSet:
                    self.fut = newFuture[void]()
                    self.futIsSet = true
                await self.fut

proc release(self: var AsyncLockHold) =
    if self.held:
        self.held = false#Mark this ref instance as not held to prevent double release
        self.parent.held = false
        if self.parent.futIsSet:
            self.parent.fut.complete()#Wake one waiter to let them know the lock has been released
            self.parent.futIsSet = false#Treat the future as no longer present

    else:
        raise newException(ValueError, "Attempt to release an AsyncLockHold that is not held")