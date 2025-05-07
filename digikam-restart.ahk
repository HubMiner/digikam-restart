; AutoHotkey Script to Gracefully Close digikam.exe, Force-Close after Timeout, and Restart

#NoEnv
SendMode Input
SetBatchLines, -1

processName := "digikam.exe"
timeoutSeconds := 3600   ; 60 minutes timeout

; Check if digikam.exe is running
Process, Exist, %processName%
if (ErrorLevel)
{
    ; Attempt to close all windows belonging to digikam.exe gracefully.
    ; This sends a WM_CLOSE message (0x10) to each window belonging to the process.
    WinGet, winList, List, ahk_exe %processName%
    if (winList > 0)
    {
        Loop, %winList%
        {
            winID := winList%A_Index%
            PostMessage, 0x10, 0, 0,, ahk_id %winID%
        }
    }
    else
    {
        ; If no windows are found but the process is running (perhaps a background service),
        ; you might opt to try a default close command. (Note: many background apps might not respond to this.)
        Process, Close, %processName%
    }
    
    ; Wait for the process to close gracefully within the timeout period.
    startTime := A_TickCount
    while (true)
    {
        Process, Exist, %processName%
        if (ErrorLevel = 0)
            break  ; The process has exited gracefully.
        
        elapsed := (A_TickCount - startTime) / 1000  ; elapsed time in seconds
        if (elapsed >= timeoutSeconds)
            break  ; Timeout reached
        Sleep, 1000  ; Check every second.
    }
    
    ; If the process is still running after the timeout, forcefully terminate it and its child processes.
    Process, Exist, %processName%
    if (ErrorLevel)
    {
        Run, % "taskkill /T /F /IM " . processName, , Hide
        Sleep, 2000  ; Give a moment for forceful termination to complete.
    }
}

; Final check: Ensure no instance of digikam.exe remains.
Process, Exist, %processName%
if (ErrorLevel)
{
    MsgBox, 16, Error, % "Failed to close all " processName " processes."
    ExitApp
}

; Relaunch DigiKam.
Run, %processName%
ExitApp
