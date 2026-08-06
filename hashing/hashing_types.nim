#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                        Type definitions for the hashing library
#------------------------------------------------------------------------------------------------------------------------------------------------------

#Define a type for the "fhash", this should always be used in place of array[20, byte] when using a hash as it allows it to be easily changed in the future
type FHash = array[20, byte]
type FHash2 = array[32, byte]#Used for 256bit hash type rather than the 160bit sha1 based hashes

#Define types for the state that is used when calculating a hash by updating with multiple blocks of data
type FHashState[T: static int] = ref object
    digestCalced: bool = false#Used to allow for repeat calls to digest without recalculating
    
    when T == 1:
        digest: FHash
        when USE_NIM_CRYPTO:
            state: nimcrypto.sha1
        else:
            state: Sha1State

    elif T == 2:
        digest: FHash2
        when USE_NIM_CRYPTO:
            state: nimcrypto.sha512
        else:
            state: ShaStateStatic[Sha_512]