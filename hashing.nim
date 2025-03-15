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

#Only include the file hashing functions on systems that are 32bit or larger and not standalone
when sizeof(int) >= 4 and not defined(standalone):
    #Define a function that will be used to calculate the hash of a file on disk by passing in a path and optionally specifying the block size to read the file in
    proc calcFileHash(path: string, BlockSize: static int=(1024*1024)): FHash =#Default to 1MB blocks as this is a good mix between memeory usage and performance on HDDs/IOPS limited systems
        var buff: array[BlockSize, char]

        #Define a hash state object for the file
        var hashState = newSha1State()

        #Open the file for reading and read until we reach EOF
        with open(path, fmRead) as f:
            while true:
                #Read a block of data from the file into the buffer and return the number of bytes read
                let bytesRead = f.readChars(buff, 0, BlockSize)

                #If we have reached the end of the file break the loop so we can finalise the hash
                if bytesRead == 0:
                    break

                hashState.update(buff[0..<bytesRead])

        #Return the hash of the file
        let resp = hashState.finalize()
        return cast[FHash](resp)