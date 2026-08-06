#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                    Implements hashing using a state that is periodically updated with new data 
#------------------------------------------------------------------------------------------------------------------------------------------------------

#Create a state for incremental hashing that digests to a FHash
func newFHash(): FHashState[1] =
    result = FHashState[1]()

    when USE_NIM_CRYPTO:
        result.state.init()

#Create an FHash state for the version 2 hash type that digests to a FHash2
func newFHash2(): FHashState[2] =
    result = FHashState[2]()

    when USE_NIM_CRYPTO:
        result.state.init()

#Update the hash state with more data
func update[T](self: FHashState[T], data: string|seq[byte]|seq[char]) {.inline.} =
    when T == 1:
        self.state.update(data)
    elif T == 2:
        self.state.update(data)
    else:
        throw "Invalid type for FHashState, must be 1 or 2"

    if self.digestCalced:
        self.digestCalced = false

#Calculate the hash digest using the current state
func digest[T](self: FHashState[T]): FHash|FHash2 {.inline.} =
    if self.digestCalced:
        return self.digest

    when T == 1:
        when USE_NIM_CRYPTO:
            self.digest = cast[FHash](self.state.finish())
        else:
            self.digest = cast[FHash](self.state.finalize())
    elif T == 2:
        when USE_NIM_CRYPTO:
            let digestRaw = self.state.finish()
        else:
            digestRaw = self.state.finalize()
        self.digest = cast[ptr FHash2](digestRaw.addr)[]

    else:
        throw "Invalid type for FHashState, must be 1 or 2"

    self.digestCalced = true
    return self.digest

#Sugar for calculating the hash and then converting to a hex string
func hexDigest[T](self: FHashState[T]): string {.inline.} =
    let data = self.digest()    
    return data.toHex()

#[

var hashState: nimcrypto.sha1
hashState.init()

hashState.update("Hello World")
echo cast[FHash](hashState.finish()).toHex()

]#
