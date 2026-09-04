#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                    Implements locks for parallel async IO operations
#------------------------------------------------------------------------------------------------------------------------------------------------------
#Standard lock that allows for a single operation to be performed at a time
type AsyncLock = ref object
    held: bool = false    
    futIsSet: bool = false#If the future exists
    fut: Future[void]

#Object that is returned when a lock is acquire, this ensures that the lock cannot be released by logic that did not acquire it
type AsyncLockHold = object
    parent: AsyncLock
    held: bool = true

#Lock that allows for both non exclusive and exclusive operations, all non exclusive locks must release before the exclusive lock can be acquired
type AsyncLockDual = ref object
    exclPending: bool = false#If an exclusive lock is pending, this prevents new non exclusive locks from being acquired
    heldExclusive: bool = false#If the lock is held exclusively
    heldNonExclusive: int = 0#The number of non exclusive locks that are currently held
    trigger: AsyncTrigger#An async trigger is used as its fired each time a lock is released (or either kind)

type AsyncLockDualHold = object
    parent: AsyncLockDual
    heldExclusive: bool = false#If the lock is held exclusively
    heldNonExclusive: bool = false#If the lock is held non exclusively

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

#---------------------------------- Methods for the dual mode lock ---------------------------------
proc newAsyncLockDual(): AsyncLockDual =
    result = AsyncLockDual(
        trigger: newAsyncTrigger(true)#Auto reset trigger
    )

proc acquire(self: AsyncLockDual, exclusive: bool = false, timeout: auto = 0): Future[Opt[AsyncLockDualHold]] {.async.} =
    let tOut = timeout.uint64

    if self.exclPending:
        self.exclPending = true#Mark that an exclusive lock is pending, this prevents new non exclusive locks from being acquired

    if tOut > 0:
        let start = time_ms()
        while true:
            if exclusive:
                if not self.heldExclusive and self.heldNonExclusive == 0:
                    self.heldExclusive = true
                    self.exclPending = false#Clear the exclusive pending flag since we have acquired the exclusive lock
                    return som(AsyncLockDualHold(parent: self, heldExclusive: true))
            else:
                if not self.exclPending and not self.heldExclusive:
                    self.heldNonExclusive += 1
                    return som(AsyncLockDualHold(parent: self, heldNonExclusive: true))

            #Calculate how long we can wait for the lock to be acquired before the timeout is reached
            let elapsed = time_ms() - start
            let remaining = tOut - elapsed
            
            if elapsed > tOut or remaining <= 0:
                return non[AsyncLockDualHold]()

            #Wait until the lock is available or the timeout is reached
            await (self.trigger.wait() or sleepAsync(remaining.int))

    else:
        while true:
            if exclusive:
                if not self.heldExclusive and self.heldNonExclusive == 0:
                    self.heldExclusive = true
                    self.exclPending = false#Clear the exclusive pending flag since we have acquired the exclusive lock
                    return som(AsyncLockDualHold(parent: self, heldExclusive: true))
            else:
                if not self.exclPending and not self.heldExclusive:
                    self.heldNonExclusive += 1
                    return som(AsyncLockDualHold(parent: self, heldNonExclusive: true))
            await self.trigger.wait()

proc release(self: var AsyncLockDualHold) =
    if self.heldExclusive:
        self.heldExclusive = false#Mark this ref instance as not held to prevent double release
        self.parent.heldExclusive = false
        self.parent.trigger.set()#Wake any waiting locks to have them retry to acquire the lock(only the first one will succeed)
    elif self.heldNonExclusive:
        self.heldNonExclusive = false#Mark this ref instance as not held to prevent double release
        self.parent.heldNonExclusive -= 1
        self.parent.trigger.set()#Wake any waiting locks to have them retry to acquire the lock
    else:
        raise newException(ValueError, "Attempt to release an AsyncLockDualHold that is not held")
