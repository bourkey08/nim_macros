#------------------------------------------------------------------------------------------------------------------------------------------------------
#                        Implements an async limiter that allows for limiting bandwith usage to a fixed value per window of time
#------------------------------------------------------------------------------------------------------------------------------------------------------
#Define the default window size for the bandwith limiter
const DEFAULT_BWLIMITER_WINDOW_SIZE = 1000#Default window size in ms

#---------------------------------------- Type definitions  ----------------------------------------
type AsyncBWLimiter* = ref object
    sets: tuple[
        limit: uint64,#Bandwith limit in bytes per window
        windowSize: uint64#Window size in ms
    ]

    lastUpdate: uint64 = 0#Last time the window was updated to factor in passed time
    curValue: uint64 = 0#Current byte count for the limiter

#----------------------------- Define the constructors for the limiter -----------------------------
proc newAsyncBWLimiter*(limit: uint64|int, windowSize: uint64|int = DEFAULT_BWLIMITER_WINDOW_SIZE): AsyncBWLimiter =
    result = AsyncBWLimiter(
        sets: (limit: uint64(limit), windowSize: uint64(windowSize)),
        lastUpdate: time_ms()#Set to now so that the first check will be correct
    )

template newAsyncBWLimiter*(limit: string, windowSize: uint64|int = DEFAULT_BWLIMITER_WINDOW_SIZE): AsyncBWLimiter =
    var intLimit = parseBinaryUnits(limit)

    #Handle the limit being passed in bits instead of bytes
    if limit.contains("b"):
        intLimit = intLimit div 8

    newAsyncBWLimiter(intLimit, windowSize)

#--------------- Define the methods for working with the limiter both sync and async ---------------

## Called to update the limiter with the number of bytes that have been used without first checking if there is enough bandwidth available
proc update*(self: AsyncBWLimiter, bytes: uint64|int) = 
    let now = time_ms()

    #Update the current value of the limiter based on the time passed
    let timeDiff = now - self.lastUpdate

    #If a full window has passed since the last update then reset the current value to 0
    if timeDiff >= self.sets.windowSize:
        self.curValue = 0
        self.lastUpdate = now

    else:#Otherwise calculate the number of bytes to remove as a fraction of the window
        let toRemove = (self.sets.limit * timeDiff) div self.sets.windowSize

        if toRemove >= self.curValue:
            self.curValue = 0
        else:
            self.curValue -= toRemove
        self.lastUpdate = now

    self.curValue += uint64(bytes)

## Returns true/false indicating if there is enough bandwidth available for a requested number of bytes
proc check*(self: AsyncBWLimiter, bytes: uint64|int): bool =
    #First check if the request can be handled without updating the limiter
    if self.curValue + uint64(bytes) <= self.sets.limit:
        return true

    #Otherwise update the limiter and check again
    self.update(0)

    #Handle the case where the request is larger than the limiter, this will only be allowed if the limiter is empty
    if self.curValue == 0 and uint64(bytes) >= self.sets.limit:
        return true

    else:
        if self.curValue + uint64(bytes) <= self.sets.limit:
            return true
        else:
            return false
    
## Returns the number of milliseconds that need to be waited before rechecking if there is enough bandwith for a given request
proc getDelay*(self: AsyncBWLimiter, bytes: uint64|int): int =
    #Check if the request can be handled without updating the limiter
    if self.curValue + uint64(bytes) <= self.sets.limit:
        return 0

    #If the request is larger than the limiter then handle this as a special case 
    if bytes.uint64 >= self.sets.limit:
        return int(self.sets.windowSize)

    else:#Otherwise calculate the fraction of the window we need to wait based on the current free space
        let bytesToFree = (bytes.uint64 + self.curValue) - self.sets.limit

        let delay = (bytesToFree * self.sets.windowSize) div self.sets.limit
        return int(delay)

## Waits until there is enough bandwidth available for a requested number of bytes and then consumes the bytes from the limiter
## Returns false if the timeout is reached first and true if the bytes were successfully consumed from the limiter
proc checkUpdate*(self: AsyncBWLimiter, bytes: uint64|int, timeout: int|uint64 = 0): Future[bool] {.async.} =
    let startTime = time_ms()#Time we started waiting for the bandwidth to be allocated

    var now = time_ms()#This will be updated each loop with the current time

    while timeout == 0 or (now - startTime) < timeout.uint64:
        if self.check(bytes):
            self.update(bytes)
            return true

        else:
            var delay = self.getDelay(bytes).uint64

            #If a timeout is specified then check if the delay will exceed the timeout and adjust accordingly
            if timeout > 0 and ((now - startTime) + delay) > timeout.uint64:
                delay = timeout.uint64 - (now - startTime)

                if delay == 0:#If the calculate delay is 0 then we have reached the timeout and should return false
                    return false

            if delay > 0:#Ensure there is a delay otherwise wait for 1ms to avoid busy waiting, this may happen if a very small number of extra bytes are needed
                await sleepAsync(delay.int)
            else:
                await sleepAsync(1)#Sleep for 1ms to avoid busy waiting

        now = time_ms()