#This is the main entry point into the standard library written by bourkey08

#This is the main entry point into the standard library written by bourkey08
when not declared(with):    
    include "./num_utils.nim"
    include "./binaryops.nim"
    include "./utils.nim"
    include "./str_utils.nim"
    include "./seq_utils.nim"
    include "./binaryunits.nim"
    include "./memory.nim"
    include "./debug_tools.nim"     
    include "./benchmark.nim"
    include "./options.nim"
    include "./static_strings.nim"

    when declared(async):
        include "./async_helpers/async_helpers.nim"

    when not defined(js):  
        include "./hashing.nim"   
        include "./network.nim"  

        when defined(linux) or defined(macosx) or defined(windows):    
            include "./system.nim"    
            include "./config.nim"

        #Incldue the arduino specific functions only when the arduino flag is set
        when declared(arduino):
            include "./arduino/arduino.nim"

        when not defined(standalone):
            when not declared(AsyncCond):
                import "./concurrency.nim"
            when declared(Thread):
                include "./parallel_utils.nim"

    #The standard library time functions dont work properly on 8bit microcontrollers, i havent tested them on 16bit but expect this to fail as well due to assumption that int can be used to store an i32
    when sizeof(int) >= 4:
        import "./time.nim"  

    when declared(bconsole):
        include "./console.nim"

    when defined(js):
        include "./js.nim"

when defined(simd):
    when defined(release):
        {.passC: "-march=native -O3 -mtune=intel -msse4.2 -ftree-vectorize -fopt-info-vec -fno-strict-aliasing".}#-msse4.2
