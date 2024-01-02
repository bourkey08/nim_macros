#Implements functions/macros for console interfaces to programs
import json, times, macros, asyncdispatch
import std/terminal

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