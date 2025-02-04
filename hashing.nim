#Implements a few shortcuts for hashing functions
#Note: None of these are intended to be secure they are for hashing keys in tables/btrees ect
import checksums/sha1
import std/bitops

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

#Define functions to get a portion of the hash as unsigned ints of various lengths
#These ints will have even distribution over a smaller keyspace, useful for hash table sharding/data partitioning
func u8(fhash: FHash): uint8 {.inline} =
    return uint8(fhash[0])    

func u16(fhash: FHash): uint16 {.inline} =
    return bitxor(
        (uint16(fhash[0]) << 8),
        (uint16(fhash[1]))
    )
    

func u32(fhash: FHash): uint32 {.inline} =
    return bitxor(
        (uint32(fhash[0]) << 24),
        (uint32(fhash[1]) << 16),
        (uint32(fhash[2]) << 8),
        (uint32(fhash[3]))
    )

func u64(fhash: FHash): uint64 {.inline.} =
    return bitxor(
        uint64(fhash[0]) << 56,
        uint64(fhash[1]) << 48,
        uint64(fhash[2]) << 40,
        uint64(fhash[3]) << 32,
        uint64(fhash[4]) << 24,
        uint64(fhash[5]) << 16,
        uint64(fhash[6]) << 8,
        uint64(fhash[7])
    )   

#Now define functions for getting the hash as arrays of various lengths/types, used when we want the value as a 64bit or 128bit vector for simd accelerated code
func u8x16(fhash: FHash): array[16, uint8] {.inline.} = 
    return [
        fhash[0],
        fhash[1],
        fhash[2],
        fhash[3],
        fhash[4],
        fhash[5],
        fhash[6],
        fhash[7],
        fhash[8],
        fhash[9],
        fhash[10],
        fhash[11],
        fhash[12],
        fhash[13],
        fhash[14],
        fhash[15]
    ]

func u8x8(fhash: FHash): array[8, uint8] {.inline.} =
    return [
        fhash[0],
        fhash[1],
        fhash[2],
        fhash[3],
        fhash[4],
        fhash[5],
        fhash[6],
        fhash[7]
    ]

func u16x8(fhash: FHash): array[8, uint16] {.inline.} =
    return [
        bitxor(uint16(fhash[0]) << 8, uint16(fhash[1])),
        bitxor(uint16(fhash[2]) << 8, uint16(fhash[3])),
        bitxor(uint16(fhash[4]) << 8, uint16(fhash[5])),
        bitxor(uint16(fhash[6]) << 8, uint16(fhash[7])),
        bitxor(uint16(fhash[8]) << 8, uint16(fhash[9])),
        bitxor(uint16(fhash[10]) << 8, uint16(fhash[11])),
        bitxor(uint16(fhash[12]) << 8, uint16(fhash[13])),
        bitxor(uint16(fhash[14]) << 8, uint16(fhash[15])),
    ]

func u16x4(fhash: FHash): array[4, uint16] {.inline.} =
    return [
        bitxor(uint16(fhash[0]) << 8, uint16(fhash[1])),
        bitxor(uint16(fhash[2]) << 8, uint16(fhash[3])),
        bitxor(uint16(fhash[4]) << 8, uint16(fhash[5])),
        bitxor(uint16(fhash[6]) << 8, uint16(fhash[7]))
    ]

func u32x4(fhash: FHash): array[4, uint32] {.inline.} =
    return [
        bitxor(uint32(fhash[0]) << 24, uint32(fhash[1]) << 16, uint32(fhash[2]) << 8, uint32(fhash[3])),
        bitxor(uint32(fhash[4]) << 24, uint32(fhash[5]) << 16, uint32(fhash[6]) << 8, uint32(fhash[7])),
        bitxor(uint32(fhash[8]) << 24, uint32(fhash[9]) << 16, uint32(fhash[10]) << 8, uint32(fhash[11])),
        bitxor(uint32(fhash[12]) << 24, uint32(fhash[13]) << 16, uint32(fhash[14]) << 8, uint32(fhash[15]))
    ]

func u32x2(fhash: FHash): array[2, uint32] {.inline.} =
    return [
        bitxor(uint32(fhash[0]) << 24, uint32(fhash[1]) << 16, uint32(fhash[2]) << 8, uint32(fhash[3])),
        bitxor(uint32(fhash[4]) << 24, uint32(fhash[5]) << 16, uint32(fhash[6]) << 8, uint32(fhash[7]))
    ]

func u64x2(fhash: FHash): array[2, uint64] {.inline.} =
    return [
        bitxor(
            uint64(fhash[0]) << 56,
            uint64(fhash[1]) << 48,
            uint64(fhash[2]) << 40,
            uint64(fhash[3]) << 32,
            uint64(fhash[4]) << 24,
            uint64(fhash[5]) << 16,
            uint64(fhash[6]) << 8,
            uint64(fhash[7])
        ),
        bitxor(
            uint64(fhash[8]) << 56,
            uint64(fhash[9]) << 48,
            uint64(fhash[10]) << 40,
            uint64(fhash[11]) << 32,
            uint64(fhash[12]) << 24,
            uint64(fhash[13]) << 16,
            uint64(fhash[14]) << 8,
            uint64(fhash[15])
        )
    ]