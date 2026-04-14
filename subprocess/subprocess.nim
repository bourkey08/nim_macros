#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                Implements async functionality for launching subprocesses and handling there output
#------------------------------------------------------------------------------------------------------------------------------------------------------
const SUBPROC_TICK_RATE = 10#How oftern to check for output from the subprocess in milliseconds, this is a balance between responsiveness and cpu usage

import std/[osproc, asyncdispatch, strutils, streams, asyncstreams, os]

#Define the return types for the 2 run functions
type SubProcResult = tuple[exitCode: int, stdOut: string, stdErr: string]
type SubProcStream = tuple[exitCode: Future[int], stdOut: FutureStream[string], stdErr: FutureStream[string]]

#Called to run a sub process with the provided command and working directory and capture the output
#This accumulates all output in memory before returning
#   - this is suitable for most use cases but if you need to process the output as it comes in then use the runSubProcStream function instead    
proc runSubProc(cmd: string, workingDir: string="", args: seq[string] = @[]): Future[SubProcResult] {.async.} =
    var subProc: Process
    if args.len > 0:
        subProc = osproc.startProcess(
            cmd,
            args=args,
            workingDir=workingDir,
            options={poUsePath}
        )
    else:
        subProc = osproc.startProcess(
            cmd,
            workingDir=workingDir,
            options={poUsePath, poEvalCommand}
        )

    #Now async await the process to complete and then read the output code from the temp file
    var stdOutBuffer: seq[string] = @[]
    var stdErrBuffer: seq[string] = @[]

    var errStream = subProc.peekableErrorStream()
    var outStream = subProc.peekableOutputStream()

    #Define a template for capturing output as we need it twice
    template captureOutput(): untyped =        
        expandLoop src, {errStream, outStream}:
            tmp = src.peekStr(0xffff)
            tmp = src.readStr(tmp.len)
            if tmp.len > 0:
                if src == errStream:
                    stdErrBuffer.add tmp
                else:
                    stdOutBuffer.add tmp

    #Wait for the subprocess to exit while reading output as it runs to prevent it halting if the buffers fiill up    
    var tmp: string
    while subProc.running():
        captureOutput()
        await sleepAsync(SUBPROC_TICK_RATE)

    #Ensure the process completed succesfully before trying to read the output file
    let exitCode = subProc.waitForExit()#We already waited for the process to complete async so this should return immediately, this is just to get the exit code

    #Finally process any remaining output
    captureOutput()
    
    return (exitCode, stdOutBuffer.join(""), stdErrBuffer.join(""))

#Runs a sub process and returns the stdout and stderr as async streams that can be processed as the output is produced,
#  - suitable for long running processes or processes that produce large output
proc runSubProcStream(cmd: string, workingDir: string="", args: seq[string] = @[]): SubProcStream = 
    #Define an async function that handles actually running the subprocess and capturing output
    #  - This needs to keep running after the function returns to continue capturing output
    proc procRunnerWrapper(cmd: string, workingDir: string, stdOutStream: FutureStream[string], stdErrStream: FutureStream[string], exitCodeFuture: Future[int]) {.async.} =
        var subProc: Process
        if args.len > 0:
            subProc = osproc.startProcess(
                cmd,
                args=args,
                workingDir=workingDir,
                options={poUsePath}
            )

        else:
            subProc = osproc.startProcess(
                cmd,
                workingDir=workingDir,
                options={poUsePath, poEvalCommand}
            )

        #Get the sync streams from the subprocess and convert them to async streams
        var errStream = subProc.peekableErrorStream()
        var outStream = subProc.peekableOutputStream()

        #Define a template for capturing output as we need it twice
        template captureOutput(): untyped =        
            expandLoop src, {errStream, outStream}:
                tmp = src.peekStr(0xffff)
                tmp = src.readStr(tmp.len)
                if tmp.len > 0:
                    if src == errStream:
                        await stdErrStream.write(tmp)
                    else:
                        await stdOutStream.write(tmp)

        #Wait for the subprocess to exit while reading output as it runs to prevent it halting if the buffers fiill up    
        var tmp: string
        while subProc.running():
            captureOutput()
            await sleepAsync(SUBPROC_TICK_RATE)

        #Ensure the process completed succesfully before trying to read the output file
        let exitCode = subProc.waitForExit()#We already waited for the process to complete async so this should return immediately, this is just to get the exit code

        #Finally process any remaining output
        captureOutput()

        #Set the exit code and complete both streams to indicate they are finished/closed
        stdErrStream.complete()
        stdOutStream.complete()
        exitCodeFuture.complete(exitCode)

    #Create the streams and exit code future to be returned
    var stdOutStream = newFutureStream[string]()
    var stdErrStream = newFutureStream[string]()
    var exitCodeFuture = newFuture[int]()

    #Start the sub process
    asyncCheck procRunnerWrapper(cmd, workingDir, stdOutStream, stdErrStream, exitCodeFuture)

    #Now return the futures and streams
    return (exitCodeFuture, stdOutStream, stdErrStream)
