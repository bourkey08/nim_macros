#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                            Implements methods for converting hashes to and from hex strings
#------------------------------------------------------------------------------------------------------------------------------------------------------

#Convert a hash to a hex string
func `$`(h: FHash|FHash2): string {.inline.} =
    return h.toHex()

#Parse a hex string into a hash
func parseFHash(hexStr: string): FHash =
    if hexStr.len != 40:
        raise newException(ValueError, "Invalid hash length, expected 40 characters for a SHA1 hash")

    let bytes = hexStr.toUpper().fromHex()
    var hash: FHash
    for i in 0..<20:
        hash[i] = bytes[i]
    return hash

func parseFHash2(hexStr: string): FHash2 =
    if hexStr.len != 64:
        raise newException(ValueError, "Invalid hash length, expected 64 characters for a SHA256 hash")

    let bytes = hexStr.toUpper().fromHex()
    var hash: FHash2
    for i in 0..<32:
        hash[i] = bytes[i]
    return hash
