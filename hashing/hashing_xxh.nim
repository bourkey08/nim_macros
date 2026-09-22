#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                Implements methods with a similar interface to the fHash methods for using xxh3 hashing
#------------------------------------------------------------------------------------------------------------------------------------------------------

#Define a type for the xxh hashes, this will be defined as FHashX
#Existing hash types:
#   - FHash - sha1
#   - FHash2 - sha512[:32]

macro BuildXXHashs(): untyped =
    result = newStmtList()

    for w in [32, 64, 128]:
        #Add the type definition for the xxhash type
        let typeIdent = newIdentNode("FHashX" & $w)        
        result.add quote do:
            when `w` == 32:
                type `typeIdent` = distinct uint32
            elif `w` == 64:
                type `typeIdent` = distinct uint64
            elif `w` == 128:
                type `typeIdent` = distinct array[16, byte]
        
        #Handle string representation of the hash
        let dollar = newIdentNode("$")
        result.add quote do:
            func `dollar`(v: `typeIdent`): string {.inline.} =
                ## Converts the hash to a hex string
                when `w` == 32:
                    return cast[array[4, byte]](v).toHex()
                elif `w` == 64:
                    return $(cast[uint64](v))
                    return cast[array[8, byte]](v).toHex()
                elif `w` == 128:
                    return cast[array[16, byte]](v).toHex()
                else:
                    discard

        #Add the standard call -> resp function for quick hash calcs
        #Needs the handle the following argument types
        #   - string
        #   - seq[byte]
        #   - seq[char]
        #   - array[byte]
        #   - array[char]
        let funcName = newIdentNode("calcFHashX" & $w)
        result.add quote do:
            func `funcName`(data: string): `typeIdent` {.inline.} =
                ## Calculates the xxhash of the data and returns it as a `typeIdent`
                when `w` == 32:
                    return `typeIdent`(XXH32(data))
                elif `w` == 64:
                    return `typeIdent`(XXH64(data))
                else:
                    let h = XXH3_128bits(data)
                    return `typeIdent`(cast[array[16, byte]](h))  

            func `funcName`(data: openArray[char|byte]): `typeIdent` {.inline.} =
                let p = cast[ptr UncheckedArray[byte]](data[0].addr)
                let l = cast[csize_t](data.len)

                when `w` == 32:
                    return `typeIdent`(XXH32(p, l, 0.uint32))

                elif `w` == 64:
                    return `typeIdent`(XXH64(p, l, 0.uint64))

                else:
                    let h = XXH3_128bits(p, l)
                    return `typeIdent`(cast[array[16, byte]](h))            
        
        #Add methods for creating a hash state and then updating with more data
        let stateType = newIdentNode("FHashX" & $w & "State")
        var stateIntType: NimNode

        case w:#Define the internal state type
        of 32:
            stateIntType = newIdentNode("Xxh32State")
        of 64:
            stateIntType = newIdentNode("Xxh64State")
        of 128:
            stateIntType = newIdentNode("Xxh128State")
        else:
            raise newException(Exception, "Error in XXH Hashing macro, invalid hash")
        
        #Create the state object with its internal type for holding the underlying state object
        result.add quote do:
            type `stateType` = ref object
                digestCalced: bool = false
                digest: `typeIdent`
                state: `stateIntType`

        #Define the constructor function
        let contructorName = newIdentNode("newFHashX" & $w)
        result.add quote do:
            func `contructorName`(): `stateType` =
                when `w` == 32:
                    result = `stateType`(
                        state: newXxh32()
                    )
                elif `w` == 64:
                    result = `stateType`(
                        state: newXxh64()
                    )
                else:
                    result = `stateType`(
                        state: newXxh128()
                    )

        #Update method
        let update = newIdentNode("update")

        #Update the state with more data
        result.add quote do:
            func `update`(self: `stateType`, data: string) {.inline.} =
                self.state.update(data)

            func `update`(self: `stateType`, data: openArray[char]) {.inline.} =
                var d = newString(data.len)
                copyMem(d[0].addr, data[0].addr, data.len)
                self.state.update(d)

            func `update`(self: `stateType`, data: openArray[byte]) {.inline.} =
                var d = newString(data.len)
                copyMem(d[0].addr, data[0].addr, data.len)                
                self.state.update(d)

        #Digest methods for the hashes
        let digestFunc = newIdentNode("digest")
        let digestFuncHex = newIdentNode("hexdigest")

        result.add quote do:
            func `digestFunc`(self: `stateType`): `typeIdent` {.inline.} =
                #If the digest has not already been calculated then do that now
                if not self.digestCalced:
                    self.digestCalced = true
                    self.digest = `typeIdent`(cast[`typeIdent`](self.state.digest()))
                    
                return self.digest

            func `digestFuncHex`(self: `stateType`): string {.inline.} =
                when `w` == 32:
                    let d = cast[array[4, byte]](self.digest())
                elif `w` == 64:
                    let d = cast[array[8, byte]](self.digest())
                else:
                    let d = cast[array[16, byte]](self.digest())                
                return d.toHex()              
                
        #Add file hashing methods when building for windows or linux
        when defined(linux) or defined(windows):
            let fileFuncName = newIdentNode("calcFileHashX" & $w)
            let fileFuncNameAsync = newIdentNode("aCalcFileHashX" & $w)#Variant of the function that uses async IO operations
            
            result.add quote do:
                proc `fileFuncName`(path: string, BlockSize: static int=(1024*1024)): `typeIdent` =#Default to 1MB blocks as this is a good mix between memeory usage and performance on HDDs/IOPS limited systems
                    #Create a hashing object for calculating the file hash
                    var hashState = `contructorName`()

                    #Define the read buffer used for file io
                    var buff: array[BlockSize, char]

                    #Open the file for reading and read until we reach EOF
                    with open(path, fmRead) as f:
                        while true:
                            #Read a block of data from the file into the buffer and return the number of bytes read
                            let bytesRead = f.readChars(buff, 0, BlockSize)

                            #If we have reached the end of the file break the loop so we can finalise the hash
                            if bytesRead == 0:
                                break

                            let bytes = buff[0..<bytesRead]

                            hashState.`update`(bytes)

                    return hashState.`digestFunc`()

            #Only add the async method if async file is available
            when declared(asyncfile):
                result.add quote do:
                    proc `fileFuncNameAsync`(path: string, BlockSize: static int=(1024*1024)): Future[`typeIdent`] {.async.} =#Default to 1MB blocks as this is a good mix between memeory usage and performance on HDDs/IOPS limited systems
                        #Create a hashing object for calculating the file hash
                        var hashState = `contructorName`()

                        #Define the read buffer used for file io
                        var buff: array[BlockSize, char]

                        #Open the file for reading and read until we reach EOF
                        with openasync(path, fmRead) as f:
                            while true:
                                #Read a block of data from the file into the buffer and return the number of bytes read
                                let bytesRead = await f.readBuffer(buff[0].addr, BlockSize)

                                #If we have reached the end of the file break the loop so we can finalise the hash
                                if bytesRead == 0:
                                    break

                                let bytes = buff[0..<bytesRead]

                                hashState.`update`(bytes)

                        return hashState.`digestFunc`()

        #Define comparison operators for the hashes
        let comparEq = newIdentNode("==")
        result.add quote do:
            func `comparEq`(x, y: `typeIdent`): bool {.inline.} =
                when `w` == 32:
                    return cast[uint32](x) == cast[uint32](y)

                elif `w` == 64:
                    return cast[uint64](x) == cast[uint64](y)
                
                else:#128 bit
                    return cast[array[16, byte]](x) == cast[array[16, byte]](y)
BuildXXHashs()
