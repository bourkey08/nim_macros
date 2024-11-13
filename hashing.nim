#Implements a few shortcuts for hashing functions
#Note: None of these are intended to be secure they are for hashing keys in tables/btrees ect
import checksums/sha1

#Define a type for the "fhash", this should always be used in place of array[20, byte] when using a hash as it allows it to be easily changed in the future
type FHash = array[20, byte]

#Takes a string and calculates the hash returning it as a fhash (20 bytes) rather than a hex string
func calcFHash(data: string): FHash {.inline.} =  
    let resp = secureHash(data)
    return cast[FHash](resp)

#As above but for sequences of characters
func calcFHash(data: openArray[char]): FHash {.inline.} =  
    let resp = secureHash(data)
    return cast[FHash](resp)

#As above but for sequences of bytes
#Note: This will be slower then the other 2 options as it requires copying the data to a sequence of characters
#      Will rewrite this as a macro thats more efficient in the future
func calcFHash[T](data: seq[T]): FHash {.inline.} =
    #Convert the argument to a sequence of characters
    var arry: seq[char]
    for c in data:
        arry.add(char(c))

    let resp = secureHash(arry)
    return cast[FHash](resp)