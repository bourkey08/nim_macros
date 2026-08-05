#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                        Implements fixed length heap allocated arrays with a size set at runtime
#------------------------------------------------------------------------------------------------------------------------------------------------------

#---------------------------------------------- Types ----------------------------------------------
#Type for a heap allocated array with a sized set at runtime
type dArray*[T] = ref object 
    size: int
    freed: bool = false#Flag that is set to true once the array has been freed from memory
    data: ptr UncheckedArray[T]

#----------------------------------- Constructors and Destructors ----------------------------------
# Define a destructor for this specific type of the dynamic array to free its memory when it goes out of scope    
proc `=destroy`[T: typedesc](x: var typeof dArray[T]()[]) =
    if not x.freed:
        dealloc(cast[pointer](x.data))
        x.freed = true

#Allocate a new dynamic array of a given size and type
proc newdArray*[T](size: int): dArray[T] =
    #Create an object for the dynamically allocated array
    result = dArray[T](
        size: size,
        data: cast[ptr UncheckedArray[T]](alloc(size * sizeof(T)))
    )

## Called to explicitly free the memory used by the dynamic array
proc destroy*[T](self: dArray[T]) =
    ## Frees the memory used by the dynamic array
    if not self.freed:
        dealloc(cast[pointer](self.data))
        self.freed = true

## Alias for destroy to free the memory used by the dynamic array
proc free*[T](self: dArray[T]) =
    ## Frees the memory used by the dynamic array
    self.destroy()

#------------------------- Properties for accessing data on the array type -------------------------
## Returns the element at the given index in the array
template `[]`*[T](self: dArray[T], index: int|int16|int32|int64|uint16|uint32|uint64): T =
    let idx = int(index)
    if idx < 0 or idx >= self.size:
        raise newException(IndexError, "Index out of bounds")
    self.data[idx]

#Getter for slicing the dynamic array using a range
template `[]`*[T](self: dArray[T], slice: HSlice[int, int]): seq[T] =
    ## Returns a sequence containing the elements in the given range of the dynamic array
    if slice.a < 0 or slice.b >= self.size:
        raise newException(IndexError, "Slice out of bounds")

    let length = slice.b - slice.a + 1
    var resp = newSeq[T](length)

    for i in 0..<length:
        resp[i] = self.data[slice.a + i]
    resp

## Sets the element at the given index in the array to the given value
template `[]=`*[T](self: dArray[T], index: int|int16|int32|int64|uint16|uint32|uint64, value: T) =
    let idx = int(index)
    if idx < 0 or idx >= self.size:
        raise newException(IndexError, "Index out of bounds")
    self.data[idx] = value

## Returns the total number of allocated elements in the array (not the number of elements stored or the byte size of the array)
proc `len`*[T](self: dArray[T]): int {.inline.} =
    return self.size