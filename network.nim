#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                        Defines misc helpers for networking
#------------------------------------------------------------------------------------------------------------------------------------------------------
import std/[net, asyncnet]

#Helper to allow sending byte sequences over an async udp socket
template sendTo(self: AsyncSocket, address: string, port: Port|uint16|uint32|uint64|int|int16|int32|int64, data: seq[byte]): untyped =
    let byteStr = data.toString()
    self.sendTo(address, Port(port), byteStr)
