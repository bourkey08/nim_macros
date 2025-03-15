#Implements the single write protocol that uses 28 bits to send a byte handling syncronization and power delivery over the same wire\
type BSWire = object
    pin: uint8
    io_clk: uint16#IO clock speed in microseconds
    buffer: array[28, bool]#Buffer to store retreived bits in
    buffer_pos: uint8 = 0
    

proc newBSWire(pin: uint8, io_clk: uint16): BSWire =
    result = BSWire(
        pin: pin,
        io_clk: io_clk   
    )

