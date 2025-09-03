#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                        Implements a simple string type that can be allocated on the stack
#------------------------------------------------------------------------------------------------------------------------------------------------------

type sString[S] = object
    len: uint16
    data: array[S, char]

macro `:=`[S](self: sString[S], other: string): untyped =
    result = quote do:
        if `other`.len > `self`.data.len:
            raise newException(ValueError, "String too long to assign to sString")

        `self`.len = `other`.len.uint16
        for i in 0..<`other`.len:
            `self`.data[i] = `other`[i]

func `$`[S](self: sString[S]): string {.inline.} =
    result = ""
    for i in 0..<self.len.int:
        result.add(self.data[i])

func `==`[S1, S2](a: sString[S1], b: sString[S2]): bool {.inline.} =
    if a.len != b.len:
        return false

    for i in 0..<a.len.int:
        if a.data[i] != b.data[i]:
            return false

    return true

func `!=`[S1, S2](a: sString[S1], b: sString[S2]): bool {.inline.} =
    result = not (a == b)

func `+=`[S](a: var sString[S], b: string) {.inline.} =
    if a.len.int + b.len > a.data.len:
        raise newException(ValueError, "String too long to append to sString")

    for i in 0..<b.len:
        a.data[a.len.int + i] = b[i]
    a.len = a.len.uint16 + b.len.uint16

func toBytes[S](self: sString[S]): array[S, byte]{.inline.} =
    for i in 0..<self.len.int:
        result[i] = byte(self.data[i])

func u8[S](self: sString[S]): seq[byte] {.inline.} =
    result = newSeq[byte](self.len.int)
    for i in 0..<self.len.int:
        result[i] = byte(self.data[i])

func `&`[S](a: sString[S], b: string): sString[S] {.inline.} =
    result = a
    result += b

func `contains`[S](a: sString[S], b: string): bool {.inline.} =
    if b.len > a.len.int:
        return false

    for i in 0..(a.len.int - b.len):
        var match = true
        for j in 0..<b.len:
            if a.data[i + j] != b[j]:
                match = false
                break
        if match:
            return true

    return false

func `[]`[S](a: sString[S], idx: int): char {.inline.} =
    if idx < 0 or idx >= a.len.int:
        raise newException(IndexError, "Index out of bounds")
    result = a.data[idx]

func `[]=`[S](a: var sString[S], idx: int, c: char) {.inline.} =
    if idx < 0 or idx >= a.len.int:
        raise newException(IndexError, "Index out of bounds")
    a.data[idx] = c
