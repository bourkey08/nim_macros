#----------------------------------------------------------------------------------------------------------------------------------------------------------------------
#    Implements  a single lock that takes a dual lock as its parent, this lock will then get a non exclusive lock on the parent lock as well as its own lock on acquire
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------

#-------------------------------------------------------- Define the types for the tiered lock -------------------------------------------------------

type AsyncLockTiered = ref object
    parentLock: AsyncLockDual#The parent lock that is used to acquire a non exclusive lock on when this lock is acquired
    held: bool = false#If the lock is held exclusively
    futIsSet: bool = false#If the future exists
    fut: Future[void]

type AsyncLockTieredHold = object
    parent: AsyncLockTiered
    parentLock: AsyncLockDualHold#The parent lock object also needs to be released on release of this lock
    held: bool = true

#------------------------------------------------------- Define the methods for the tiered lock ------------------------------------------------------

proc newAsyncLockTiered(parent: AsyncLockDual): AsyncLockTiered =
    result = AsyncLockTiered(
        parentLock: parent
    )

#Called to acquire the lock, waits for the lock to become available before returning
proc acquire(self: AsyncLockTiered, timeout: auto = 0): Future[Opt[AsyncLockTieredHold]] {.async.} =
    let tOut = timeout.uint64

    if tOut > 0:
        let start = time_ms()
        while true:
            if not self.held and not self.parentLock.heldExclusive:#If this lock is already held or the parent lock is held exclusively then we cannot acquire this lock yet
                #Check if the parent lock can be acquired non exclusively, if it can then acquire it and return the tiered lock
                let (pOk, pLock) = await self.parentLock.acquire(false, tOut)

                if pOk:
                    self.held = true
                    var respLock = AsyncLockTieredHold(parent: self, parentLock: pLock)
                    return som(respLock)
            
            #Calculate how long we can wait for the lock to be acquired before the timeout is reached
            let elapsed = time_ms() - start
            let remaining = tOut - elapsed
            
            if elapsed > tOut or remaining <= 0:
                break#Return non since we have timed out waiting for the lock to be acquired

            #Wait until the lock is available or the timeout is reached
            if not self.futIsSet:
                self.fut = newFuture[void]()
                self.futIsSet = true
            await (self.fut or sleepAsync(remaining.int))
    else:
        while true:#Loop until the lock is acquired
            if not self.held:                
                #Check if the parent lock can be acquired non exclusively, if it can then acquire it and return the tiered lock
                let (pOk, pLock) = await self.parentLock.acquire(false)

                if pOk:
                    self.held = true
                    var respLock = AsyncLockTieredHold(parent: self, parentLock: pLock)

                    return som(respLock)

            if not self.futIsSet:
                self.fut = newFuture[void]()
                self.futIsSet = true
            await self.fut

proc release(self: var AsyncLockTieredHold) =
    if self.held:
        self.held = false#Mark this ref instance as not held to prevent double release
        self.parent.held = false
        if self.parent.futIsSet:
            self.parent.fut.complete()#Wake one waiter to let them know the lock has been released
            self.parent.futIsSet = false#Treat the future as no longer present
            
            
        #Release the parent lock as well
        self.parentLock.release()

    else:
        raise newException(ValueError, "Attempt to release an AsyncLockHold that is not held")
