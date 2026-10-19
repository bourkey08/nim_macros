#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                    Implements macros to simplify working with locks
#------------------------------------------------------------------------------------------------------------------------------------------------------

#Hold the given lock while executing the body of code, then release the lock when the body is complete
macro withLock*(lock: AsyncLock|AsyncLockDual|AsyncLockTiered, body: untyped, exclusive: bool = false, timeout: SomeInteger = 0): untyped =    
    ## Acquires the specified lock, executes the provided code and then releases the lock
    var lockHold = newIdentNode("lockHold")

    result = quote do:
        block:
            when `lock` is AsyncLock:
                var `lockHold` = await `lock`.acquire(timeout = `timeout`)
            
            elif `lock` is AsyncLockDual:
                var `lockHold` = await `lock`.acquire(exclusive=exclusive, timeout = `timeout`)

            elif `lock` is AsyncLockTiered:
                var `lockHold` = await `lock`.acquire(timeout = `timeout`)

            if not `lockHold`.isSome:
                raise newException(ValueError, "Failed to acquire the lock within the specified timeout")

            try:
                `body`
            finally:
                `lockHold`.get().release()

#Now define overloads for alternative arguments/orders to allow for the body always being last when optional arguments are specified
macro withLock*(lock: AsyncLock|AsyncLockDual|AsyncLockTiered, timeout: SomeInteger, body: untyped): untyped =
    result = quote do:
        withLock(`lock`, `body`, timeout = `timeout`)

macro withLock*(lock: AsyncLock|AsyncLockDual|AsyncLockTiered, exclusive: bool, body: untyped): untyped =
    result = quote do:
        withLock(`lock`, `body`, exclusive = `exclusive`)

macro withLock*(lock: AsyncLock|AsyncLockDual|AsyncLockTiered, exclusive: bool, timeout: SomeInteger, body: untyped): untyped =
    result = quote do:
        withLock(`lock`, `body`, exclusive = `exclusive`, timeout = `timeout`)

macro withLock*(lock: AsyncLock|AsyncLockDual|AsyncLockTiered, timeout: SomeInteger, exclusive: bool, body: untyped): untyped =
    result = quote do:
        withLock(`lock`, `body`, exclusive = `exclusive`, timeout = `timeout`)