#Implements functions/macros for console interfaces to programs
import json, macros, asyncdispatch
import std/[terminal, os, strutils, strformat, times, math]

#Define a macro for response, this will call .response with the data converted to json
macro Response(data: untyped) =
    result = quote do:
        #Encode the data as json using the json macro and then convert that to a string before echoing it
        echo $(%*`data`)

#Define an object for a progress bar that can be updated as a file download or an operation progresses
type ProgressBarState = ref object
    #Label for the progress bar
    Label: string
    Progress: uint32
    Max: uint32
    Round: uint32#Round to this many digits (defaults to 2)
    Units: seq[string]#Units to display (defaults to %)
    Width: uint32#Width of the progress bar (defaults to 20)
    Drawn: bool = false#Whether or not the progress bar has been drawn yet

    ShowUnits: bool = true#Whether or not to show the units
    ShowEta: bool = true#Whether or not to show the estimated time remaining
    MultiUnits: bool = false#Whether or not to use teried units (e.g. 1.2K instead of 1200)
    TeirThresh: uint32 = 1000#The threshold for using teried units (defaults to 1000)

    StartTime: float64 = 0#The time at which the progress bar was first drawn

#Define a function for updating the progress bar or drawing it to the console if it has not yet been drawn
proc DrawProgressBarState(self: ProgressBarState) =
    #If the progress bar has not yet got a start time set then set one now
    if self.StartTime == 0:
        self.StartTime = times.epochTime()

    #Calculate the percentage
    var Percent = (float64(self.Progress) / float64(self.Max)) * float64(100)

    #Calculate the number of characters to draw
    var NumChars = uint32((Percent / float64(100)) * float32(self.Width))

    #Calculate the number of spaces to draw
    var NumSpaces = self.Width - NumChars

    #Build the updated progress bar in a string variable
    var Bar = "["
 
    #Add the correct number of =s to the progress bar
    if NumChars > 0:
        for i in 0..NumChars-1:
            Bar = Bar & "="

    #Now add a > if the progress bar is not full
    if NumChars < self.Width:
        Bar = Bar & ">"
    else:
        #Otherwise add a final equals to fill the bar space
        Bar = Bar & "="

    #Add the correct number of spaces to the progress bar
    if NumSpaces > 0:
        for i in 0..NumSpaces-1:
            Bar = Bar & " "

    #Add the closing tag
    Bar = Bar & "]"

    #If show units is set to true then display the actual value along with its units
    if self.ShowUnits:
        #Calculate the units to use
        var Units = self.Units[0]

        #Calculate the value to display
        var Value = float64(self.Progress)

        #If multi units is set to true then use teried units
        if self.MultiUnits:
            var UnitIndex = 0

            if Value >= float64(self.TeirThresh):
                Value /= float64(self.TeirThresh)
                UnitIndex += 1
                
                Units = self.Units[UnitIndex]

        #Round the value to the correct number of digits
        Value = Value * (float64(10) ** float64(self.Round)) / float64(10 ** self.Round)

        #Add the value to the progress bar
        Bar = Bar & " " & $Value & Units

    #If show eta is set to true then display the estimated time remaining
    if self.ShowEta:
        #Calculate the time elapsed
        var Elapsed = times.epochTime() - self.StartTime

        #Calculate the time remaining
        var Remaining = (Elapsed / float64(self.Progress)) * float64(self.Max - self.Progress)

        #Round the time remaining to the nearest second
        var Eta = uint32(Remaining)

        #Now convert this to a string with H/M/S
        #Start by getting the hours, minutes and seconds as strings
        var Hours: string = $(Eta div 3600)
        Eta -= uint32(Eta div 3600) * 3600

        var Minutes: string = $(Eta div 60)
        Eta -= uint32(Eta div 60) * 60

        var Seconds = $Eta        
        
        #Build the eta string
        Bar = Bar & " - ETA: "

        #Check if there is an hour to display
        if Hours != "0":
            #Make sure each of the values is two digits long
            if Hours.len < 2:
                Hours = "0" & Hours

            if Minutes.len < 2:
                Minutes = "0" & Minutes

            if Seconds.len < 2:
                Seconds = "0" & Seconds

            Bar = Bar & Hours & ":" & Minutes & ":" & Seconds & "s"

        elif Minutes != "0":
            #Make sure each of the values is two digits long
            if Minutes.len < 2:
                Minutes = "0" & Minutes

            if Seconds.len < 2:
                Seconds = "0" & Seconds

            Bar = Bar & Minutes & ":" & Seconds & "s"

        else:
            #Make sure each of the values is two digits long
            if Seconds.len < 2:
                Seconds = "0" & Seconds

            Bar = Bar & Seconds & "s"

    #Hide the cursor so that it doesn't flicker
    stdout.hideCursor()

    if self.Drawn:
        stdout.eraseLine()

    else:
        #Set the drawn flag to true
        self.Drawn = true

    #Write the progress bar to the console
    stdout.write("\r" & Bar)

    #And show the cursor again
    stdout.showCursor()

#Define a function for creating a new progress bar
proc ProgressBar*(Label: string, Max: uint32, Round: uint32 = 2, Units: string = "%", Width: uint32 = 60): ProgressBarState =
    result = new(ProgressBarState)
    result.Label = Label
    result.Max = Max
    result.Round = Round
    result.Units = @[Units]
    result.Width = Width
    result.Progress = 0

    #Print the initial progress bar
    DrawProgressBarState(result)

#Define a generic type for status screen
type StatusScreen = ref object
    title: seq[string]#Title of the status screen, multiple entrys are treated as multiple lines
    status: string
    action: string
    progress: uint32
    maxProgress: uint32 
    units: seq[string] = @["B/s", "KB/s", "MB/s", "GB/s", "TB/s", "PB/s"] #Units used for speed
    unitDivisor: float64 = 1024.0#Divisor used to calculate which unit to use
    round: uint32 = 2#Number of decimal places to round to for both speed and progress %age
    startTime: float64#Timestamp when the current action was started. used to calc ETA and speeds
    lastUpdate: float64#Timestamp when the last update was made. used to calc speeds
    
    displayAction: bool = false#Whether or not to display the action
    displaySpeed: bool = false#Whether or not to display the download speed
    displayEta: bool = false#Whether or not to display the estimated time remaining
    displayProgress: bool = false#Whether or not to display the progress bar

    width: uint32 = 0#Max Width of the status screen, for fit to width
    center: bool = true#Whether or not to center the status screen in the console
    extraFields: seq[tuple[key: string, value: string]]#Extra fields to display in the status screen in the format key: value

#Define a function for displaying the status screen to the console, this clears the screen prior to drawing the status screen
proc display(self: var StatusScreen) =
    #Define helper functions for formatting part of a line
    #Takes a key and value and formats them into a line for the status screen excluding the borders but including the padding
    func formatLine(key: string, value: string, width: int): string {.inline.} = 
        let data = key & ": " & value
        let padding = width - data.len - 2

        return data & " ".repeat(padding)

    func centerLine(text: string, width: int): string {.inline.} =
        #This acts as floor division as the result is forced to an int
        let padding = int((width - text.len) / 2) - 1
        var val = " ".repeat(padding) & text & " ".repeat(padding)

        #This handles the case where the width of the terminal is an odd number by adding a space to the end of the line (as we cant center it perfectly)
        if val.len < width-2:
            val = val & " "

        return val

    #And define the functions that are used to draw whole lines to the screen
    proc titleLines(title: seq[string], width: int) {.inline.} =
        for line in title:
            stdout.write("│" & centerLine(line, width) & "│")

    proc displayAction(self: var StatusScreen, width: int) {.inline.}  =
        if self.displayAction:
            stdout.write("│" & formatLine("Action", self.action, width) & "│")

    proc displaySpeed(self: var StatusScreen, width: int) {.inline.}  =
        if self.displaySpeed:
            var speedStr: string            
            var unitIndex = 0

            if self.progress == 0:
                speedStr = "0.00"
            else:
                #Calculate the speed based on the time stamps
                var speed = float(self.progress) / (self.lastUpdate - self.startTime)            

                #Find the correct unit to use
                while speed > self.unitDivisor and unitIndex < self.units.len - 1:
                    speed = speed / self.unitDivisor
                    unitIndex += 1

                #Now get the speed as a string rounded to the correct number of decimal places
                speedStr = $(int(speed * float(float pow(10, float self.round))))

                #Insert the decimal point
                speedStr = speedStr[0..^3] & "." & speedStr[^2..^1]            

            stdout.write("│" & formatLine("Download Speed", fmt"{speedStr} {self.units[unitIndex]}", width) & "│")

    proc displayEta(self: var StatusScreen, width: int) {.inline.}  =
        if self.displayEta:
            #Calculate the time remaining based on the time elapsed and the progress
            let timeElapsed = self.lastUpdate - self.startTime
            let timeRemaining = (float(self.maxProgress) - float(self.progress)) / (float(self.progress) / timeElapsed)

            #Now take the seconds remaining and convert that to days, hours, minutes and seconds
            var remaining: array[4, int] = [
                int(timeRemaining / 86400),
                int(timeRemaining / 3600) mod 24,
                int(timeRemaining / 60) mod 60,
                int(timeRemaining) mod 60
            ]

            for i in 0..3:
                if remaining[i] < 0:
                    remaining[i] = 0

            #And assemble a string from the array, we will always display at least minutes and seconds
            var remStr = fmt"{($remaining[2]).align(2, '0')}:{($remaining[3]).align(2, '0')}"
            
            if remaining[1] > 0 or remaining[0] > 0:#Handle hours if days is > 0 or hours is > 0
                remStr = fmt"{($remaining[1]).align(2, '0')}:" & remStr

            if remaining[0] > 0:#Handle days if days is > 0
                remStr = fmt"{($remaining[0]).align(2, '0')} days - " & remStr 

            stdout.write("│" & formatLine("Time Remaining", remStr, width) & "│")

    proc displayProgress(self: var StatusScreen, width: int) {.inline.} =
        #Given a progress percentage and a width returns a string representing a progress bar
        func progBar(perc: float, width: int): string {.inline.} =
            #Set the constant to use for the filled, unfilled and divider chars, this could be moved to the config for the status screen
            let ccFil = "="
            let ccUnf = "."
            let ccDiv = ">"

            #Now calculate the widths of the 2 sections to match the overall bar width
            let fillWidth = int((perc / 100) * float(width - 2))    
            let unfWidth = width - 2 - fillWidth

            var bar = fmt"[{ccFil.repeat(fillWidth)}{ccDiv}{ccUnf.repeat(unfWidth)}]"

            return bar

        if self.displayProgress:
            #Calculate the percentage of the progress
            var percent = (float(self.progress) / float(self.maxProgress)) * 100
            if percent > 100:#Handle ignoring any percentages beyond 100 
                percent = 100

            #Now build the % string section formatted to the correct number of decimal places
            var percentStr = $(int(percent * pow(10.0, float self.round)))
            if percentStr.len < 3:#Only occours if the value is 0
                if self.round == 0:
                    percentStr = "0"
                else:
                    percentStr = "0." & "0".repeat(self.round)
            else:
                #Insert the decimal point
                percentStr = percentStr[0..^3] & "." & percentStr[^2..^1]

            let progStr = progBar(percent, width - 26)

            stdout.write("│" & formatLine("Progress", fmt"{progStr}   {percentStr}%", width) & "│")

    proc displayExtraFields(self: var StatusScreen, width: int) {.inline.} =
        for field in self.extraFields:
            stdout.write("│" & formatLine(field.key, field.value, width) & "│")

    #Get the height and width of the terminal, this is then used for calculating widths and centering elements
    let width = terminalWidth()
    let height = terminalHeight()

    #Clear the screen
    stdout.eraseScreen()
    stdout.hideCursor()

    #Back to the top left of the screen
    stdout.setCursorXPos(0)
    stdout.setCursorYPos(0)

    #Draw the bounding box for the status screen
    #Header section
    stdout.write("┌" & "─".repeat(width - 2) & "┐")
    titleLines(self.title, width)
    stdout.write("├" & "─".repeat(width - 2) & "┤")

    #Body section    
    stdout.write("│" & formatLine("Status", self.status, width) & "│")#Status is always shown
    
    displayAction(self, width)
    displayProgress(self, width)
    displaySpeed(self, width)
    displayEta(self, width)
    displayExtraFields(self, width)

    stdout.write("└" & "─".repeat(width - 2) & "┘")

    #Now flush the buffer to ensure the console is updated 
    #stdout.flushFile()
    stdout.resetAttributes()

#Define a function for creating a new status screen
proc newStatusScreen(title: string, maxProgress: uint32, status: string = "", action: string = ""): StatusScreen =
    var result = StatusScreen(
        title: @[title],
        status: status,
        action: action,
        progress: 0,
        maxProgress: maxProgress,
        startTime: epochTime(),
        lastUpdate: epochTime()        
    )

    return result

proc newStatusScreen(title: seq[string], maxProgress: uint32, status: string = "", action: string = ""): StatusScreen =
    var result = StatusScreen(
        title: title,
        status: status,
        action: action,
        progress: 0,
        maxProgress: maxProgress,
        startTime: epochTime(),
        lastUpdate: epochTime()        
    )

    return result

#Define functions for updating the status screens
proc updateStatus(self: var StatusScreen, status: string = "", action: string = "") =
    if status.len > 0:
        self.status = status
    if action.len > 0:
        self.action = action
    self.lastUpdate = epochTime()

proc updateProgress(self: var StatusScreen, progress: int) = 
    self.progress += uint32 progress
    self.lastUpdate = epochTime()

proc updateTitle(self: var StatusScreen, title: string) =
    self.title = @[title]

proc updateTitle(self: var StatusScreen, title: seq[string]) =
    self.title = title

proc updateDisplay(self: StatusScreen, action: bool, eta: bool, speed: bool, progress: bool) =
    self.displayAction = action
    self.displayEta = eta
    self.displaySpeed = speed
    self.displayProgress = progress
