# PROJECT: digikam-restart

# Purpose
* Gracefully restart Windows digikam.
* This will resync metadata (when using lazy sync) and should clear out unexpected behavior.

# Functionality
* The script will send WM_CLOSE message (please close yourself) to each running process and subproces related to digikam.  This will allow digikam to finish any pending tasks andto to exit normally.
* If digikam process is still running after 1 hour limit, it will forcefully terminated (risk of data loss).
* Finally, the script will restart digikam.

# Setup
1. Install AutoHotKey: https://www.autohotkey.com/
1. Install Digikam: https://www.digikam.org/download/
1. git-clone or download this repo.
1. Update the Windows PATH variable to include path to folder containing digikam.exe
1. Be safe: review the .ahk script before running it on your computer.  Ask a human or AI for help if you don't understand it.  Don't run random things you don't understand.
1. Right click the "Reopen-Digikam.ahk" script and compile it.  EXE file will be created.
1. Test EXE by running it.  Use Task Manager or Process Explorer to monitor the state of the digikam.exe process and its subprocesses.
1. Create a Windows shortcut as desired.

