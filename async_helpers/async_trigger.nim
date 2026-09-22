#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                Defines a trigger that can be used to allow 1 async process to wake up/trigger another
#------------------------------------------------------------------------------------------------------------------------------------------------------

#Defines a type for a generic object for an auto resetting async trigger
type AsyncTrigger = ref object
    isSet: bool
    autoReset: bool
    futCreated: bool = false
    futSet: bool = false
    fut: Future[void]

#Constructor for the async trigger object
proc newAsyncTrigger(autoReset: bool = true): AsyncTrigger =
    result = AsyncTrigger(
        isSet: false,
        autoReset: autoReset,
        futCreated: false,
        futSet: false
    )

#Called to set the trigger/wake any waiters
proc set(self: AsyncTrigger) =
    if self.isSet:
        return

    #If the trigger auto resets then we dont want to see isSet but need to create a new future immediatly
    if self.autoReset:
        if self.futCreated and not self.futSet:
            self.fut.complete()

            #Now create a new future for the next waiter
            self.fut = newFuture[void]()
            self.futCreated = true
            self.futSet = false

    else:#Manual reset trigger
        if self.futCreated and not self.futSet:
            self.fut.complete()
            self.futSet = true
            self.isSet = true

#Called to reset the trigger if it is a manual reset trigger
proc reset(self: AsyncTrigger) = 
    if self.autoReset:
        return

    if self.isSet:
        self.isSet = false
        self.fut = newFuture[void]()
        self.futCreated = true
        self.futSet = false

#Called to wait for the trigger to be set
proc wait(self: AsyncTrigger): Future[void] {.async.} =
    if self.isSet:#Already set so return immediately
        return
    else:
        if not self.futCreated:
            self.fut = newFuture[void]()
            self.futCreated = true
            self.futSet = false

        await self.fut