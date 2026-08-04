#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                    Implements a simplified option type that outpreforms the built in std/options type
#------------------------------------------------------------------------------------------------------------------------------------------------------

#------------------------------------------ Optional type ------------------------------------------
#Option type, has sets if the value is present, val is undefined if has is false and should not be accessed
type Opt[T] = tuple[
    has: bool,
    val: T
]

#Define templates for the standard option operations to allow this to be a drop in replacement for the std/options type
template isSome[T](self: Opt[T]): bool =
    self.has

template isNone[T](self: Opt[T]): bool =
    not self.has

template get[T](self: Opt[T]): T =
    if not self.has:
        raise newException(ValueError, "Option value is not set")
    self.val
    
#As these methods have the same name and calling pattern as the std/options type they are renamed to some = som and none = non to avoid conflicts
template som[T](val: T): untyped =
    (true, val)

template non[T](): untyped =
    (false, default(T))    


#--------------------------- Optional type with error message on failure ---------------------------
type OptE[T] = tuple[
    has: bool,
    val: T,
    eMsg: string,
    eCode: uint32
]

template isSome[T](self: OptE[T]): bool =
    self.has 

template isNone[T](self: OptE[T]): bool =
    not self.has

template get[T](self: OptE[T]): T =
    if not self.has:
        raise newException(ValueError, "Option value is not set, error code: " & $self.eCode & ", error message: " & self.eMsg)
    self.val

template getErr[T](self: OptE[T]): untyped =
    if self.has:
        raise newException(ValueError, "Option value is set, no error to get")
    (self.eCode, self.eMsg)

template respSuccess[T](val: T): untyped =
    (true, val, "", 0)#Need to set the unused fields as its a tuple

template respError[T](eCode: uint32, eMsg: string): untyped =
    (false, default(T), eMsg, eCode)