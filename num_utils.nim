import macros

#------------------------------------------------------------------------------------------------------------------------------------------------------
#            Define a function that formats a number as a string optionally rounding to a fixed number of digits and with thousand seperators
#------------------------------------------------------------------------------------------------------------------------------------------------------

template formatNumber(num: any, arg1: static auto = -2, arg2: static auto = -2): string =
    when not declared(getStrasInt):
        func getStrasInt(arg: static string): int {.compiletime.} =
            var i1: int
            try:
                i1 = parseInt(arg)
                return i1
            except:
                return -1
        
    #Define a template for the seperator to avoid code duplication
    when not declared(handleSeperator):
        template handleSeperator(val: static string): string =
            when val == "true":
                ","
            elif val == "false" or val == "":
                ""
            else:
                val

    #Set the thousands and roundTo values based on our arguments
    when arg1 is string and arg2 is string:#This should not be used but one of them must be an int as a string
        #Attempt to get both the values as integers
        const i1 = getStrasInt(arg1)
        const i2 = getStrasInt(arg2)

        when i1 == -1 and i2 == -1:
            throw "formatNumber: Called with two string arguments, expected format is formatNumber(num, thousands: bool|string, roundTo: int)"

        when i1 != -1 and i2 != -1:#Called with 2 integer strings, this is also an error
            throw "formatNumber: Called with two string arguments, expected format is formatNumber(num, thousands: bool|string, roundTo: int)"

        when i1 == -1:#Otherwise we have 1 number and 1 bool or string
            const roundTo = i2

            #Set the thousands seperator based on the remaining argument, treat "true" and "false" as booleans using , as the default seperator for true
            const thousands = handleSeperator(arg1) 
            
        else:#i2 == -1
            const roundTo = i1
            const thousands = handleSeperator(arg2)
    else:
        #Handle error cases
        when arg1 is bool and arg2 is bool:
            throw "formatNumber: Called with two boolean arguments, expected format is formatNumber(num, thousands: bool|string, roundTo: int)"

        else:
            when arg1 is int|int8|int16|int32|int64|uint8|uint16|uint32|uint64|float|float32|float64 and arg2 is int|int8|int16|int32|int64|uint8|uint16|uint32|uint64|float|float32|float64:
                #Check if either of the values is -2, if it is then this is treated as no argument passed for that parameter so we need to work out what the remaining val is
                when arg1 == int(-2) and arg2 == int(-2):
                    discard#Do nothing let the default values be used

                when arg1 == int(-2):
                    const roundTo = arg2

                when arg2 == int(-2):
                    const roundTo = arg1                    

                else:#Otherwise 2 actual numbers is an error
                    throw "formatNumber: Called with two numeric arguments, expected format is formatNumber(num, thousands: bool|string, roundTo: int)"
            else:
                #Hendle the case where 1 arg is a string
                when arg1 is string:
                    const inum = getStrasInt(arg1)
                    when inum == -1:
                        when arg1 == "true":
                            const thousands = ","                

                        when arg1 == "false" or arg1 == "":
                            const thousands = ""

                        else:
                            const thousands = arg1

                        #Check if the other value is -2, if its not then we need to handle it
                        when arg2 != -2:
                            discard
                        when arg2 is int|int8|int16|int32|int64|uint8|uint16|uint32|uint64|float|float32|float64:
                            const roundTo = int(arg2)
                        else:
                            throw "formatNumber: Called with a string and an invalid argument, expected format is formatNumber(num, thousands: bool|string, roundTo: int)"

                else:
                    when arg2 is string:
                        const inum2 = getStrasInt(arg2)
                        when inum2 == -1:
                            when arg2 == "true":
                                const thousands = ","                

                            when arg2 == "false" or arg2 == "":
                                const thousands = ""

                            else:
                                const thousands = arg2

                            #Check if the other value is -2, if its not then we need to handle it
                            when arg1 != -2:
                                discard
                            when arg1 is int|int8|int16|int32|int64|uint8|uint16|uint32|uint64|float|float32|float64:
                                const roundTo = int(arg1)
                            else:
                                throw "formatNumber: Called with a string and an invalid argument, expected format is formatNumber(num, thousands: bool|string, roundTo: int)"

                    else:
                        when arg1 is int|int8|int16|int32|int64|uint8|uint16|uint32|uint64|float|float32|float64:
                            const roundTo = int(arg1)

                            when arg2 is bool:
                                when arg2 == true:
                                    const thousands = ","
                                else:
                                    const thousands = ""

                        else:
                            when arg2 is int|int8|int16|int32|int64|uint8|uint16|uint32|uint64|float|float32|float64:
                                const roundTo = int(arg2)

                                when arg1 is bool:
                                    when arg1 == true:
                                        const thousands = ","
                                    else:
                                        const thousands = ""
                                else:
                                    throw "formatNumber: Called with invalid arguments, expected format is formatNumber(num, thousands: bool|string, roundTo: int)"            

    #Set defaults if either value is not declared
    when not declared(roundTo):
        const roundTo = 2

    when not declared(thousands):
        const thousands = ","

    #First round the number to the specified number of digits
    when roundTo > -1 and type(num) is float|float32|float64:
        var n = $round(num, roundTo)

    else:
        #When rounding and the type is a string
        when roundTo > -1 and type(num) is string:
            var n = $round(parseFloat(num), roundTo)

        else:
            var n = $num

    #First convert the number to a string applying rounding if applicable
    when thousands == "":
        $n
    else:
        #Split the decimal part from the integer part as we dont want to add commas to the decimal part
        var parts = n.split(".")

        #Add commas to the integer part
        var outstr: string = newString(parts[0].len + (parts[0].len div 3) + 2 + parts[1].len)

        var idx: int = 0
        for i in 0..<parts[0].len:
            let x = parts[0].len - i
            if x != 0 and i != 0 and x mod 3 == 0:
                outstr[+++idx] = thousands[0]
            outstr[+++idx] = parts[0][i]

        #Now assemble the string
        if parts.len != 1:
            outstr[+++idx] = '.'
            for i in 0..<parts[1].len:
                outstr[+++idx] = parts[1][i]
        outstr