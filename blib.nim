#This is the main entry point into the standard library written by bourkey08
when not declared(with):
    include "./binaryops.nim"
    include "./utils.nim"
    include "./str_utils.nim"
    include "./num_utils.nim"
    include "./config.nim"
    include "./system.nim"
    include "./seq_utils.nim"

when declared(bconsole):
    include "./console.nim"