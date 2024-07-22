import std/parsecfg
import std/[strutils, streams, tables]

#Define a method for parsing a .ini style config file and returning a table
proc ParseConfig(path: string): Table[string, Table[string, string]] {.inline.} =
    var cfg = initTable[string, Table[string, string]]()
    var f = newFileStream(path, fmRead)
    assert f != nil, "cannot open " & path
    var p: CfgParser
    open(p, f, path)
    var section: string
    while true:
        var e = next(p)
        case e.kind
        of cfgEof: break
        of cfgSectionStart:
            section = e.section
            cfg[section] = initTable[string, string]()
        of cfgKeyValuePair:
            cfg[section][e.key] = e.value
        of cfgOption:
            cfg[section][e.key] = e.value
        of cfgError:
            echo e.msg
    close(p)
    return cfg