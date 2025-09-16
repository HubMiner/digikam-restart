$processName = "digikam.exe"
$killTimeoutSeconds = 600  # 10 minutes
$killRetryInterval = 10    # seconds

# Send a WM_CLOSE message (0x10) to each window belonging to the process.
# Add Windows API functions for window manipulation
Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Win32 {
        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
        
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
        
        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
        
        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);
        
        [DllImport("user32.dll")]
        public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    }
"@

# Send WM_CLOSE to process windows
Write-Host "Attempting graceful close of $processName..."
$WM_CLOSE = 0x10
$procs = Get-Process -Name ($processName -replace ".exe$", "") -ErrorAction SilentlyContinue
if ($procs) {
    foreach ($proc in $procs) {
        # Get child processes
        $children = Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $proc.Id }
        
        # Close main process windows
        [Win32+EnumWindowsProc]$callback = {
            param($hWnd, $lParam)
            $outPid = 0
            [Win32]::GetWindowThreadProcessId($hWnd, [ref]$outPid) | Out-Null
            if ($outPid -eq $lParam -and [Win32]::IsWindowVisible($hWnd)) {
                Write-Host "Sending WM_CLOSE to window of PID: $outPid"
                [Win32]::SendMessage($hWnd, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
            }
            return $true
        }
        [Win32]::EnumWindows($callback, [IntPtr]$proc.Id) | Out-Null
        
        # Close child process windows
        foreach ($child in $children) {
            Write-Host "Sending WM_CLOSE to child process: $($child.ProcessId)"
            [Win32]::EnumWindows($callback, [IntPtr]$child.ProcessId) | Out-Null
        }
    }
    
    # Wait a few seconds for graceful close
    Start-Sleep -Seconds 5
}



Write-Host "Final check for $processName..."
$cmd = "Get-Process -Name ($processName -replace '.exe$', '') -ErrorAction SilentlyContinue"
Write-Host "## $cmd"
$startTime = Get-Date

while ($true) {
    $procs = Get-Process -Name ($processName -replace ".exe$", "") -ErrorAction SilentlyContinue
    if (-not $procs) {
        Write-Host "$processName is no longer running."
        break
    }

    Write-Host "Failed to close all $processName processes. Attempting Stop-Process by PID..."
    foreach ($p in $procs) {
        Write-Host "Attempting Stop-Process -Id $($p.Id) -Force"
        try {
            Stop-Process -Id $p.Id -Force -ErrorAction Stop
            Write-Host "Successfully killed PID $($p.Id)"
        } catch {
            Write-Host "Failed to kill PID $($p.Id): $_"
        }
    }

    Start-Sleep -Seconds 1

    # Check again
    $cmd = "Get-Process -Name ($processName -replace '.exe$', '') -ErrorAction SilentlyContinue"
    Write-Host "## $cmd"
    $procs = Get-Process -Name ($processName -replace ".exe$", "") -ErrorAction SilentlyContinue
    if (-not $procs) {
        Write-Host "$processName successfully terminated."
        break
    }

    $elapsed = (New-TimeSpan -Start $startTime).TotalSeconds
    if ($elapsed -ge $killTimeoutSeconds) {
        Write-Host "Still failed to close all $processName processes after $killTimeoutSeconds seconds. Remaining process info:"
        foreach ($p in $procs) {
            # Use WMI to get the owner
            $owner = ""
            try {
                $wmi = Get-WmiObject Win32_Process -Filter "ProcessId = $($p.Id)"
                if ($wmi) {
                    $ownerInfo = $wmi.GetOwner()
                    if ($ownerInfo) {
                        $owner = $ownerInfo.User
                    }
                }
            } catch {
                $owner = "Unknown"
            }
            Write-Host "PID: $($p.Id), Owner: $owner, Path: $($p.Path)"
        }

        $cmd = "Add-Type -AssemblyName System.Windows.Forms"
        Write-Host "## $cmd"
        Add-Type -AssemblyName System.Windows.Forms
        $cmd = "[System.Windows.Forms.MessageBox]::Show('Failed to close all $processName processes.','Error','OK','Error')"
        Write-Host "## $cmd"
        [System.Windows.Forms.MessageBox]::Show("Failed to close all $processName processes.","Error",'OK','Error')
        exit 1
    }

    Write-Host "Waiting $killRetryInterval seconds before next kill attempt..."
    Start-Sleep -Seconds $killRetryInterval
}

Write-Host "Relaunching $processName..."
$cmd = "Start-Process -FilePath $processName -WindowStyle Normal"
$cmd = "cmd.exe /c start `"$processName`""

Write-Host "## $cmd"

Invoke-Expression $cmd
# Start-Process -FilePath $processName -WindowStyle Normal

Write-Host "# Done."
exit 0
