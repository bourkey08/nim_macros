#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                    Implements utilits for querying the hardware of the system (eg total memory)
#------------------------------------------------------------------------------------------------------------------------------------------------------

#------------------------------ Return the total memory for the system -----------------------------
when defined(windows):
    # Import Windows API types and functions
    type
        DWORDLONG = uint64
        DWORD = uint32
        MEMORYSTATUSEX {.importc: "MEMORYSTATUSEX", header: "<windows.h>".} = object
            dwLength: DWORD
            dwMemoryLoad: DWORD
            ullTotalPhys: DWORDLONG
            ullAvailPhys: DWORDLONG
            ullTotalPageFile: DWORDLONG
            ullAvailPageFile: DWORDLONG
            ullTotalVirtual: DWORDLONG
            ullAvailVirtual: DWORDLONG
            ullAvailExtendedVirtual: DWORDLONG

    #Export the GlobalMemoryStatusEx function from the Windows API
    proc globalMemoryStatusEx(lpBuffer: ptr MEMORYSTATUSEX) {.importc: "GlobalMemoryStatusEx", header: "<windows.h>", stdcall.}

    proc getTotalSystemMemory*(): uint64 =
        var memStatus: MEMORYSTATUSEX
        memStatus.dwLength = sizeof(MEMORYSTATUSEX).DWORD
        globalMemoryStatusEx(addr memStatus)
        return memStatus.ullTotalPhys

elif defined(posix):
    # Import POSIX C constants and functions
    const SC_PHYS_PAGES = 85  # Standard value, though OS specific variations exist
    const SC_PAGESIZE = 30

    #Export the equivalent of the sysconf function from the POSIX API
    proc sysconf(name: cint): clong {.importc: "sysconf", header: "<unistd.h>".}

    proc getTotalSystemMemory*(): uint64 =
        let pages = sysconf(SC_PHYS_PAGES)
        let pageSize = sysconf(SC_PAGESIZE)

        if pages > 0 and pageSize > 0:
            return uint64(pages) * uint64(pageSize)
        return 0