#This is the main entry point into the standard library written by bourkey08

#This is the main entry point into the standard library written by bourkey08
when not declared(with):    
    include "./num_utils.nim"
    include "./binaryops.nim"
    include "./utils.nim"
    include "./str_utils.nim"    
    include "./binaryunits.nim"
    include "./memory.nim"
    include "./static_strings.nim"

    when not defined(js):    
        include "./hashing.nim"   

        when defined(linux) or defined(macosx) or defined(windows):    
            include "./system.nim"    
            include "./config.nim"            
            include "./async_helpers.nim"

        #Incldue the arduino specific functions only when the arduino flag is set
        when declared(arduino):
            include "./arduino/arduino.nim"

        when not defined(standalone):
            include "./threads.nim"
            when not declared(AsyncCond):
                import "./concurrency.nim"       

    include "./seq_utils.nim" 

    #The standard library time functions dont work properly on 8bit microcontrollers, i havent tested them on 16bit but expect this to fail as well due to assumption that int can be used to store an i32
    when sizeof(int) >= 4:
        import "./time.nim"  

    when declared(bconsole):
        include "./console.nim"

    when defined(js):
        include "./js.nim"

when defined(simd):
    when defined(release):
        {.passC: "-march=native -O3 -mtune=native -ftree-vectorize -fopt-info-vec -fno-strict-aliasing".}#-msse4.2

when defined(small):
    when defined(release):
        {.passC: "-march=native -Os -mtune=native".}
