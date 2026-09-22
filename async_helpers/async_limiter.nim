#------------------------------------------------------------------------------------------------------------------------------------------------------
#                    Implements an async limiter that provides a pool for limiting the number of concurrent operations (eg downloads)
#------------------------------------------------------------------------------------------------------------------------------------------------------
#Generic type for limiting the number of actions occouring in paralell
type AsyncLimiter = ref object
    count: int
    limit: int
    trig: AsyncTrigger

type AsyncLimiterLock = ref object
    limiter: AsyncLimiter
    held: bool = true
    
#------------------------------------ Defines methods for the limiter itself ------------------------------------ 
#Define the constructor function
proc newAsyncLimiter(limit: int): AsyncLimiter =
    result = AsyncLimiter(
        count: 0,
        limit: limit, 
        trig: newAsyncTrigger(true)
    )

proc start(self: AsyncLimiter, timeout: int = 0): Future[bool] {.async.} =
    if self.limit == 0:
        return true#If the limit is 0 then there is no limit, so just return immediately

    if timeout != 0:
        let timeoutFut = sleepAsync(timeout)#Future that resolves when the timeout is reached

        while self.count >= self.limit:
            if timeoutFut.finished:
                return false
            else:
                await self.trig.wait() or timeoutFut

    else:#Otherwise wait indefinitely until there is space to start the action
        while self.count >= self.limit:
            await self.trig.wait()

    #Once there is free space then increment the counter to occupy a slot for the new action
    self.count += 1

    return true

proc finish(self: AsyncLimiter) {.inline.} =
    if self.limit == 0:
        return#If the limit is 0 then there is no limit, so just return immediately

    if self.count > 0:
        self.count -= 1

        self.trig.set()#Wake one waiter to let them know a slot has been freed up
    else:
        raise newException(ValueError, "Attempt to finish more tasks than have been started in AsyncLimiter")

#Called to reset a limiter back to 0 and wake all waiters
proc reset(self: AsyncLimiter) =
    self.count = 0
    self.trig.set()#Wake all waiters to let them know the limiter has been reset

#------------------------------------ Defines methods for the acquire/release pattern ------------------------------------
proc release(self: AsyncLimiterLock) =
    if self.limiter.limit == 0:
        return#If the limit is 0 then there is no limit, so just return immediately

    if self.held:
        self.held = false
        if self.limiter.count == 0:
            raise newException(ValueError, "Attempt to release an AsyncLimiterLock when no tasks are currently running")
        else:
            self.limiter.count -= 1
            self.limiter.trig.set()#Wake one waiter to let them know a slot has been freed up
    else:
        raise newException(ValueError, "Attempt to release an AsyncLimiterLock that is not held")

#Aquire a lock for the async limiter, returns a lock object with a release method
proc acquire(self: AsyncLimiter): Future[AsyncLimiterLock] {.async.} =
    if self.limit == 0:
        return AsyncLimiterLock(limiter: self)#
    
    else:
        while self.count >= self.limit:
            await self.trig.wait()

        self.count += 1
        
        return AsyncLimiterLock(limiter: self)