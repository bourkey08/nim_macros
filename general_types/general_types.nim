#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                                Defines misc utility types
#------------------------------------------------------------------------------------------------------------------------------------------------------


type MacAddress = array[6, byte]#Represents a mac address
type IPAddr = array[4, byte]#Represents an ipv4 address

#Represents an ipv4/port pair
type IPPort = object
    ip: IPAddr
    port: uint16


#---------------------------------------------------------- Functions for parsing an address ---------------------------------------------------------
func parseIPStr(v: string): IPAddr =
    var parts = v.split('.')
    if parts.len != 4:
        raise newException(ValueError, "Invalid IP address format")

    var ip: IPAddr
    for i in 0..<4:
        let part = parseInt(parts[i])
        if part < 0 or part > 255:
            raise newException(ValueError, "Invalid IP address format")
        ip[i] = byte(part)

    return ip

func parseIPPortStr(v: string): IPPort =
    var parts = v.split(':')
    if parts.len != 2:
        raise newException(ValueError, "Invalid IP:Port format")

    var ipPort: IPPort
    ipPort.ip = parseIPStr(parts[0])
    ipPort.port = parseInt(parts[1]).uint16

    return ipPort

func parseMacStr(v: string): MacAddress =
    var parts = v.split(':')
    if parts.len != 6:
        raise newException(ValueError, "Invalid MAC address format")

    var mac: MacAddress
    for i in 0..<6:        
        mac[i] = fromHex(parts[i])[0]

    return mac

#---------------------------------------------------- Constructors for the IPAddr and IPPort types ---------------------------------------------------

func newIPAddr(a, b, c, d: byte|uint8|uint16|uint32|uint64|int16|int32|int64|char): IPAddr =
    result[0] = byte a
    result[1] = byte b
    result[2] = byte c
    result[3] = byte d

func newIPAddr(v: string): IPAddr =
    result = parseIPStr(v)

func newIPAddr(v: openArray[byte]): IPAddr = 
    if v.len != 4:
        raise newException(ValueError, "Invalid IP address length")
    for i in 0..<4:
        result[i] = v[i]


func newIPPort(ip: IPAddr|string|openArray[byte], port: uint16): IPPort =
    result.ip = newIPAddr(ip)
    result.port = port

#Define methods to convert ips, ip:ports, and mac address to strings in the standard formats
func `$`(v: IPAddr): string {.inline.} =
    return $v[0] & "." & $v[1] & "." & $v[2] & "." & $v[3]

func `$`(v: IPPort): string {.inline.} =
    return $v.ip & ":" & $v.port

func `$`(v: MacAddress): string {.inline.} =
    return $v[0] & ":" & $v[1] & ":" & $v[2] & ":" & $v[3] & ":" & $v[4] & ":" & $v[5]