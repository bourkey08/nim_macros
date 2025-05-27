#Delay function
proc delay_ms(us: uint16) {.importc: "_delay_ms", header: "util/delay.h".}
proc delay_us(us: uint16) {.importc: "_delay_us", header: "util/delay.h".}
proc delay_ns(ns: uint32) {.importc: "_delay_ns", header: "util/delay.h".}

#Digital IO
{.pragma: digitalWrite, importc, header: "<wiring_digital.c>".}
{.pragma: digitalRead, importc, header: "<wiring_digital.c>".}
{.pragma: pinMode, importc, header: "<wiring_digital.c>".}
{.pragma: turnOffPWM, importc, header: "<wiring_digital.c>".}

proc digitalWrite*(pin: uint8, value: uint8) {.digitalWrite.}
proc digitalRead*(pin: uint8): uint8 {.digitalRead.}
proc pinMode*(pin: uint8, mode: uint8) {.pinMode.}
proc turnOffPWM*(pin: uint8) {.turnOffPWM.}

#Analog IO
{.pragma: analogRead, importc, header: "<wiring_analog.c>".}
{.pragma: analogWrite, importc, header: "<wiring_analog.c>".}
{.pragma: analogReference, importc, header: "<wiring_analog.c>".}

proc analogRead*(pin: uint8): int {.analogRead.}
proc analogWrite*(pin: uint8, value: int) {.analogWrite.}
proc analogReference*(mode: uint8) {.analogReference.}

#Now include any arduino specific sub librarys/macros
include "./bsinglewire.nim"