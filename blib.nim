#This is the main entry point into the standard library written by bourkey08

#This is the main entry point into the standard library written by bourkey08
when not declared(with):
    include "./binaryops.nim"
    include "./utils.nim"
    include "./str_utils.nim"
    include "./num_utils.nim"
    include "./config.nim"
    include "./system.nim"
    include "./seq_utils.nim"
    include "./hashing.nim"
    include "./binaryunits.nim"


    #Incldue the arduino specific functions only when the arduino flag is set
    when declared(arduino):
        include "./arduino/arduino.nim"

    #The standard library time functions dont work properly on 8bit microcontrollers, i havent tested them on 16bit but expect this to fail as well due to assumption that int can be used to store an i32
    when sizeof(int) >= 4:
        import "./time.nim"

when not declared(AsyncCond):
    import "./concurrency.nim"

when declared(bconsole):
    include "./console.nim"