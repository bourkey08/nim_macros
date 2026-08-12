#------------------------------------------------------------------------------------------------------------------------------------------------------
#            Implements an async bandwith limiter to allow efficently limiting bandwith to a specified value with a specified time window. 
#------------------------------------------------------------------------------------------------------------------------------------------------------
from "../time.nim" import time_ms

#Define the type for the bandwith limiter
type AsyncBWLimiter = ref object
    sets: tuple[
        limit: uint64,#The bandwith limit in bytes/s
        window: uint64#The time window in ms to use for the limit
    ]

    total: uint64 = 0#The total count of all bytes in the current window
    lastUpdate: uint64 = 0#The last time the limiter was updated, used to determine number of bytes to remove from total

#Define the constructor for the bandwith limiter
#This takes a bandwith limit in bytes/s and a time window in ms
proc newAsyncBWLimiter*(bandwithLimit: uint64|string, timeWindow: uint64 = 500): AsyncBWLimiter =
    when bandwithLimit is string:
        var bwLimitInt: uint64
        if "bps" in bandwithLimit:
            bwLimitInt = (parseBinaryUnits(bandwithLimit) * 8).uint64
        else:
            bwLimitInt = parseBinaryUnits(bandwithLimit).uint64

    else:
        let bwLimitInt = bandwithLimit

    var self = AsyncBWLimiter(
        sets: (
            limit: bwLimitInt,
            window: timeWindow
        ),
        lastUpdate: time_ms()#Default to the current time in ms
    )

    return self

## Called to increment the bytes downloaded by the specified count without checking the limit
proc update(self: AsyncBWLimiter, count: uint64) {.inline.} =
    let now = time_ms()

    #First check the ammount of data to remove from the total
    let timeDiff = now - self.lastUpdate

    #If the time difference is greater than the window then reset the total to 0
    if timeDiff >= self.sets.window:
        self.total = 0
    else:#Otherwise remove a fraction of the total based on time elapsed
        let removeCount = (self.total * timeDiff) div self.sets.window
        if removeCount > self.total:
            self.total = 0
        else:
            self.total -= removeCount

    #Update the stats for the limiter
    self.lastUpdate = now
    self.total = self.total + count

## Syncronous non blocking method for checking if there is enough bandwith available to update with a given count
proc check(self: AsyncBWLimiter, count: uint64): bool {.inline.} =
    #First check if there is enough bandwith to update without factoring in the time elapsed
    if self.total + count <= self.sets.limit:
        return true

    #If not check if there is enough bandwith available factoring in the time elapsed
    let now = time_ms()

    #First check the ammount of data to remove from the total
    let timeDiff = now - self.lastUpdate

    #If the time difference is greater than the window then reset the total to 0
    if timeDiff >= self.sets.window:
        return true

    else:#Otherwise remove a fraction of the total based on time elapsed
        let removeCount = (self.total * timeDiff) div self.sets.window
        if removeCount > self.total:
            return true
        else:
            let newTotal = self.total - removeCount
            if newTotal + count <= self.sets.limit:
                return true
            else:
                return false

## Combines check and update into a single method with an async sleep if the limit is reached
## This will block the current thread until the limit is available to update with the given count or the timeout is reached
proc limit(self: AsyncBWLimiter, count: uint64, timeout: uint64 = 0): Future[bool] {.async.} =
    #Check if there is enough bandwith available to update with the given count
    if self.total + count <= self.sets.limit:
        self.total += count
        return true

    let startTime = time_ms()#Time the limit was called to allow for timeout checking

    #Handle this seperatly as we need to consume multiple windows of times
    if count > self.sets.limit:
        var now = time_ms()

        var neededBytes = count 

        #Loop until the timeout is reached or we have consumed the required number of bytes
        #    - This is only used to provide a fallback for occasions where the counter is over the limit
        #    - If this is being hit frequently then the window size should be increased
        while timeout == 0 or timeout < (startTime - now):   
            now = time_ms()

            #Check if there is enough bandwith available to update with the given count
            let timeDiff = now - self.lastUpdate
            let removeCount = (self.total * timeDiff) div self.sets.window

            #Consume as many bytes as we can from the total and update the needed bytes to consume
            if removeCount > self.total:
                neededBytes -= self.total 
                self.total = 0                
            else:
                self.total -= removeCount
                neededBytes -= removeCount
            self.lastUpdate = now

            if self.total + neededBytes <= self.sets.limit:
                self.total += neededBytes
                return true

            #Not enough space after the update, calculate the ammount of time to wait before checking again
            let spaceNeeded = (self.total + neededBytes) - self.sets.limit
            let timeToWait = ((min(spaceNeeded, self.sets.limit) * self.sets.limit) div self.sets.window) + 1#Add 1 to ensure we always wait at least 1ms to

            let maxWait = tern(timeout > 0, timeout - (now-startTime) + 1, 0)
            if maxWait > 0 and timeToWait > maxWait:
                await sleepAsync(maxWait.int)
            else:
                await sleepAsync(timeToWait.int)
        return false#Default to returning false if the timeout is reached

    while true:
        let now = time_ms()

        #Check if there is enough bandwith available to update with the given count
        let timeDiff = now - self.lastUpdate
        let removeCount = (self.total * timeDiff) div self.sets.window

        if removeCount > self.total:
            self.total = 0
        else:
            self.total -= removeCount

        self.lastUpdate = now

        if self.total + count <= self.sets.limit:
            self.total += count
            return true

        #Check if the timeout has been reached and if so break
        if timeout > 0 and (now - startTime) >= timeout:
            return false

        #Not enough space after the update, calcuilate the ammount of time we should wait before checking again
        let spaceNeeded = (self.total + count) - self.sets.limit
        let timeToWait = ((spaceNeeded * self.sets.limit) div self.sets.window) + 1#Add 1 to ensure we always wait at least 1ms to avoid a busy loop

        let maxWait = tern(timeout > 0, timeout - (now-startTime)+1, 0)

        if maxWait > 0 and timeToWait > maxWait:
            await sleepAsync(maxWait.int)
        else:
            await sleepAsync(timeToWait.int)

#Add wrappers to allow calling the limiter functions with alternative interger types
template update(self: AsyncBWLimiter, count: int8|int16|int32|int64|uint8|uint16|uint32|uint64): untyped =
    self.update(count.uint64)

template check(self: AsyncBWLimiter, count: int8|int16|int32|int64|uint8|uint16|uint32|uint64): untyped =
    self.check(count.uint64)

template limit(self: AsyncBWLimiter, count: int8|int16|int32|int64|uint8|uint16|uint32|uint64, timeout: int8|int16|int32|int64|uint8|uint16|uint32|uint64 = 0): untyped =
    self.limit(count.uint64, timeout.uint64)
