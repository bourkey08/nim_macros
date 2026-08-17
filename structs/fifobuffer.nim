#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                            Implements a fast fifo buffer
#------------------------------------------------------------------------------------------------------------------------------------------------------
#Represents a block of entries in the buffer (used to allow dynamic buffer sizing while minimizing allocations)
type FIFOBufferBlock*[S: static int, T] = ref object
    buffer: array[S, T]
    len: int = 0
    addIdx: int = 0#Index to add next item
    remIdx: int = 0#Index to remove next item

type FIFOBuffer*[S: static int, T] = ref object
    blocks: seq[FIFOBufferBlock[S, T]]
    addBlockIdx: int = 0
    len*: int = 0
    
proc put*[S, T](self: FIFOBuffer[S, T], item: T) {.inline.} =
    #Get the current block index
    if self.blocks[self.addBlockIdx].len >= S:
        #Current block is full, need to add a new block
        self.blocks.add(FIFOBufferBlock[S, T]())
        self.addBlockIdx += 1

    #Add the item to the current block
    let currentBlock = self.blocks[self.addBlockIdx]
    currentBlock.buffer[currentBlock.addIdx] = item
    currentBlock.addIdx += 1
    currentBlock.len += 1
    self.len += 1

#ALias for put to add add to match sequences
template add*[S, T](self: FIFOBuffer[S, T], item: T) =
    self.put(item)

proc get*[S, T](self: FIFOBuffer[S, T]): T {.inline.} =
    while true:
        if self.blocks.len == 0:
            raise newException(ValueError, "Buffer is empty")

        if self.blocks[0].len <= self.blocks[0].remIdx:
            #Check if this block is the current add block
            if self.addBlockIdx == 0:
                raise newException(ValueError, "Buffer is empty")

            #Otherwise remove this block
            else:
                self.blocks.delete(0)
                self.addBlockIdx -= 1

        else:#Otherwise we can get an item from this block
            let currentBlock = self.blocks[0]
            result = currentBlock.buffer[currentBlock.remIdx]
            currentBlock.remIdx += 1
            self.len -= 1
            break

#Returns the next item that would be returned by get without removing it from the buffer
proc peak*[S, T](self: FIFOBuffer[S, T]): T {.inline.} =
    while true:
        if self.blocks.len == 0:
            raise newException(ValueError, "Buffer is empty")
        
        if self.blocks[0].len <= self.blocks[0].remIdx:
            #Check if this block is the current add block
            if self.addBlockIdx == 0:
                raise newException(ValueError, "Buffer is empty")

            #Otherwise remove this block
            else:
                self.blocks.delete(0)
                self.addBlockIdx -= 1

        else:#Otherwise we can get an item from this block
            let currentBlock = self.blocks[0]
            result = currentBlock.buffer[currentBlock.remIdx]
            break

proc peek*[S, T](self: FIFOBuffer[S, T]): T {.inline.} =
    return self.peak()

proc newFIFOBuffer*[S: static int, T](): FIFOBuffer[S, T] =
    result = FIFOBuffer[S, T]()

    #Create the first block
    result.blocks.add(FIFOBufferBlock[S, T]()) 
