# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║            Inventory — Automated Machine Setup Script                        ║
# ║  Generated for your account. Do not share this file — it contains a         ║
# ║  single-use credential tied to your login session.                           ║
# ║                                                                              ║
# ║  Run with:  Right-click → "Run with PowerShell"                              ║
# ║         or: powershell -ExecutionPolicy Bypass -File "machine-setup.ps1"     ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ── INJECTED CONFIGURATION (populated by the server at download time) ──────────
$ApiBaseUrl = "__API_BASE_URL__"
$SetupToken = "__SETUP_TOKEN__"
# ── END CONFIGURATION ──────────────────────────────────────────────────────────

$ErrorActionPreference = 'Stop'

# ── ASSEMBLIES ─────────────────────────────────────────────────────────────────
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# ── COLOUR PALETTE ─────────────────────────────────────────────────────────────
$C_FORM     = [System.Drawing.Color]::FromArgb(14,  14,  24)
$C_HEADER   = [System.Drawing.Color]::FromArgb(22,  22,  38)
$C_SIDEBAR  = [System.Drawing.Color]::FromArgb(18,  18,  32)
$C_LOG_BG   = [System.Drawing.Color]::FromArgb(10,  10,  20)
$C_SEP      = [System.Drawing.Color]::FromArgb(40,  40,  60)
$C_PENDING  = [System.Drawing.Color]::FromArgb(70,  70,  95)
$C_RUNNING  = [System.Drawing.Color]::FromArgb(86,  156, 214)
$C_DONE     = [System.Drawing.Color]::FromArgb(78,  201, 176)
$C_FAIL     = [System.Drawing.Color]::FromArgb(244, 71,  71)
$C_TEXT     = [System.Drawing.Color]::FromArgb(212, 212, 212)
$C_DIM      = [System.Drawing.Color]::FromArgb(100, 100, 130)
$C_LOG_NORM = [System.Drawing.Color]::FromArgb(180, 180, 210)
$C_LOG_INFO = $C_RUNNING
$C_LOG_OK   = $C_DONE
$C_LOG_WARN = [System.Drawing.Color]::FromArgb(220, 200, 80)
$C_LOG_ERR  = $C_FAIL

# ── FONTS ──────────────────────────────────────────────────────────────────────
$F_TITLE    = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$F_SUB      = New-Object System.Drawing.Font("Segoe UI", 9)
$F_STEP     = New-Object System.Drawing.Font("Segoe UI", 9)
$F_STEP_ACT = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$F_ICON     = New-Object System.Drawing.Font("Segoe UI Symbol", 11)
$F_LOG      = New-Object System.Drawing.Font("Consolas", 9)

# ── FORM ───────────────────────────────────────────────────────────────────────
$form = New-Object System.Windows.Forms.Form
$form.Text            = "Inventory — Machine Setup"
$form.ClientSize      = New-Object System.Drawing.Size(820, 548)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox     = $false
$form.BackColor       = $C_FORM
$form.ForeColor       = $C_TEXT
$form.Icon            = [System.Drawing.SystemIcons]::Application

# ── HEADER (58 px) ─────────────────────────────────────────────────────────────
$pnlHeader           = New-Object System.Windows.Forms.Panel
$pnlHeader.Dock      = "Top"
$pnlHeader.Height    = 58
$pnlHeader.BackColor = $C_HEADER
$form.Controls.Add($pnlHeader)

$lblTitle           = New-Object System.Windows.Forms.Label
$lblTitle.Text      = "Inventory — Machine Setup"
$lblTitle.Font      = $F_TITLE
$lblTitle.ForeColor = [System.Drawing.Color]::White
$lblTitle.AutoSize  = $true
$lblTitle.Location  = New-Object System.Drawing.Point(18, 10)
$pnlHeader.Controls.Add($lblTitle)

$lblSub           = New-Object System.Windows.Forms.Label
$lblSub.Text      = "Registers this machine with the Inventory system. Once complete, visit the dashboard to download your installer."
$lblSub.Font      = $F_SUB
$lblSub.ForeColor = $C_DIM
$lblSub.AutoSize  = $true
$lblSub.Location  = New-Object System.Drawing.Point(20, 36)
$pnlHeader.Controls.Add($lblSub)

# ── BOTTOM BAR (52 px) ─────────────────────────────────────────────────────────
$pnlBottom           = New-Object System.Windows.Forms.Panel
$pnlBottom.Dock      = "Bottom"
$pnlBottom.Height    = 52
$pnlBottom.BackColor = $C_HEADER
$form.Controls.Add($pnlBottom)

$pb              = New-Object System.Windows.Forms.ProgressBar
$pb.Location     = New-Object System.Drawing.Point(16, 8)
$pb.Size         = New-Object System.Drawing.Size(788, 12)
$pb.Minimum      = 0
$pb.Maximum      = 4
$pb.Value        = 0
$pb.Style        = "Continuous"
$pnlBottom.Controls.Add($pb)

$lblStatus           = New-Object System.Windows.Forms.Label
$lblStatus.Location  = New-Object System.Drawing.Point(16, 26)
$lblStatus.Size      = New-Object System.Drawing.Size(788, 18)
$lblStatus.Font      = $F_SUB
$lblStatus.ForeColor = $C_DIM
$lblStatus.Text      = "Preparing..."
$pnlBottom.Controls.Add($lblStatus)

# ── SIDEBAR (left 260 px, between header and bottom) ───────────────────────────
# Main area height: 548 - 58 - 52 = 438 px
$pnlSide           = New-Object System.Windows.Forms.Panel
$pnlSide.Location  = New-Object System.Drawing.Point(0, 58)
$pnlSide.Size      = New-Object System.Drawing.Size(260, 438)
$pnlSide.BackColor = $C_SIDEBAR
$form.Controls.Add($pnlSide)

# Vertical separator
$pnlSep           = New-Object System.Windows.Forms.Panel
$pnlSep.Location  = New-Object System.Drawing.Point(260, 58)
$pnlSep.Size      = New-Object System.Drawing.Size(1, 438)
$pnlSep.BackColor = $C_SEP
$form.Controls.Add($pnlSep)

# ── LOG PANEL (right 559 px) ────────────────────────────────────────────────────
$pnlLog           = New-Object System.Windows.Forms.Panel
$pnlLog.Location  = New-Object System.Drawing.Point(261, 58)
$pnlLog.Size      = New-Object System.Drawing.Size(559, 438)
$pnlLog.BackColor = $C_LOG_BG
$form.Controls.Add($pnlLog)

$rtb              = New-Object System.Windows.Forms.RichTextBox
$rtb.Location     = New-Object System.Drawing.Point(8, 8)
$rtb.Size         = New-Object System.Drawing.Size(543, 422)
$rtb.ReadOnly     = $true
$rtb.BackColor    = $C_LOG_BG
$rtb.ForeColor    = $C_LOG_NORM
$rtb.Font         = $F_LOG
$rtb.BorderStyle  = "None"
$rtb.ScrollBars   = "Vertical"
$rtb.WordWrap     = $false
$pnlLog.Controls.Add($rtb)

# ── STEP ROWS (8 steps, 54 px each starting at y=14) ───────────────────────────
$stepNames = @(
    "Authenticate",
    "Detect Machine UUID",
    "Detect Hostname",
    "Register Machine"
)

$stepCtrls = New-Object System.Collections.ArrayList
$stepY = 14

foreach ($i in 0..($stepNames.Count - 1)) {
    $dot            = New-Object System.Windows.Forms.Label
    $dot.Location   = New-Object System.Drawing.Point(16, ($stepY + 1))
    $dot.Size       = New-Object System.Drawing.Size(22, 22)
    $dot.Font       = $F_ICON
    $dot.ForeColor  = $C_PENDING
    $dot.Text       = [char]0x25CB   # ○ (pending)
    $dot.TextAlign  = "MiddleCenter"
    $pnlSide.Controls.Add($dot)

    $lbl            = New-Object System.Windows.Forms.Label
    $lbl.Location   = New-Object System.Drawing.Point(44, $stepY)
    $lbl.Size       = New-Object System.Drawing.Size(206, 24)
    $lbl.Font       = $F_STEP
    $lbl.ForeColor  = $C_PENDING
    $lbl.Text       = "$($i + 1).  $($stepNames[$i])"
    $lbl.TextAlign  = "MiddleLeft"
    $pnlSide.Controls.Add($lbl)

    [void]$stepCtrls.Add([pscustomobject]@{ Dot = $dot; Label = $lbl })
    $stepY += 52
}

# ── UI HELPERS ─────────────────────────────────────────────────────────────────

function DoEvents {
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-StepStatus {
    param([int]$Index, [string]$Status)
    $c = $stepCtrls[$Index]
    switch ($Status) {
        "running" {
            $c.Dot.ForeColor   = $C_RUNNING
            $c.Dot.Text        = [char]0x25B6  # ▶
            $c.Label.ForeColor = [System.Drawing.Color]::White
            $c.Label.Font      = $F_STEP_ACT
        }
        "done" {
            $c.Dot.ForeColor   = $C_DONE
            $c.Dot.Text        = [char]0x2713  # ✓
            $c.Label.ForeColor = $C_TEXT
            $c.Label.Font      = $F_STEP
        }
        "failed" {
            $c.Dot.ForeColor   = $C_FAIL
            $c.Dot.Text        = [char]0x2717  # ✗
            $c.Label.ForeColor = $C_FAIL
            $c.Label.Font      = $F_STEP
        }
    }
    DoEvents
}

function Set-Status {
    param([string]$Message)
    $lblStatus.Text = $Message
    DoEvents
}

function Set-Progress {
    param([int]$Value)
    $pb.Value = [Math]::Min($Value, $pb.Maximum)
    DoEvents
}

function Add-Log {
    param([string]$Message, [string]$Kind = "normal")
    $rtb.SelectionStart  = $rtb.TextLength
    $rtb.SelectionLength = 0
    $rtb.SelectionColor  = switch ($Kind) {
        "ok"   { $C_LOG_OK   }
        "info" { $C_LOG_INFO }
        "warn" { $C_LOG_WARN }
        "err"  { $C_LOG_ERR  }
        default { $C_LOG_NORM }
    }
    $rtb.AppendText("$Message`n")
    $rtb.ScrollToCaret()
    DoEvents
}

# ── API HELPERS ────────────────────────────────────────────────────────────────

function Invoke-Post {
    param([string]$Path, [hashtable]$Body, [string]$Token = "")
    $headers = @{ "Content-Type" = "application/json" }
    if ($Token) { $headers["Authorization"] = "Bearer $Token" }
    try {
        return Invoke-RestMethod `
            -Uri    "$ApiBaseUrl$Path" `
            -Method POST `
            -Headers $headers `
            -Body   ($Body | ConvertTo-Json -Depth 10) `
            -ErrorAction Stop
    }
    catch {
        $msg = $_.Exception.Message
        if ($_.ErrorDetails.Message) {
            try {
                $j = $_.ErrorDetails.Message | ConvertFrom-Json
                if ($j.message) {
                    $msg = if ($j.message -is [array]) { $j.message -join "; " } else { [string]$j.message }
                }
            }
            catch { }
        }
        throw $msg
    }
}

# ── STEP FUNCTIONS ─────────────────────────────────────────────────────────────

function Step-Authenticate {
    Set-StepStatus 0 "running"
    Set-Status "Authenticating..."
    Add-Log "-> Exchanging setup credentials with server..." "info"

    $result        = Invoke-Post "/setup/exchange" @{ setupToken = $SetupToken }
    $script:jwt    = $result.accessToken

    Add-Log "   Authenticated successfully." "ok"
    Set-StepStatus 0 "done"
    Set-Progress 1
}

function Step-DetectUUID {
    Set-StepStatus 1 "running"
    Set-Status "Detecting machine UUID..."
    Add-Log "-> Reading hardware UUID from WMI..." "info"

    $uuid = $null
    try {
        $uuid = (Get-CimInstance -ClassName Win32_ComputerSystemProduct -ErrorAction Stop).UUID
    }
    catch {
        # Fallback to wmic for older environments
        $raw  = & wmic csproduct get UUID /format:list 2>$null
        $line = $raw | Where-Object { $_ -match "^UUID=" } | Select-Object -First 1
        if ($line) { $uuid = $line -replace "UUID=", "" }
    }

    $uuid = if ($uuid) { $uuid.Trim().ToUpper() } else { "" }

    if (-not $uuid -or $uuid -eq "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" -or $uuid -eq "") {
        throw "Machine UUID could not be reliably determined (value: '$uuid')."
    }

    $script:machineUuid = $uuid
    Add-Log "   UUID: $($script:machineUuid)" "ok"
    Set-StepStatus 1 "done"
    Set-Progress 2
}

function Step-DetectHostname {
    Set-StepStatus 2 "running"
    Set-Status "Detecting hostname..."
    Add-Log "-> Reading computer name..." "info"

    $script:machineName = "$($env:COMPUTERNAME)'s computer"

    Add-Log "   Hostname: $($env:COMPUTERNAME)" "ok"
    Set-StepStatus 2 "done"
    Set-Progress 3
}

function Step-RegisterMachine {
    Set-StepStatus 3 "running"
    Set-Status "Registering machine..."
    Add-Log "-> Registering machine with server..." "info"

    Invoke-Post "/machines" @{
        uuid = $script:machineUuid
        name = $script:machineName
    } -Token $script:jwt | Out-Null

    Add-Log "   Machine registered: $($script:machineName)" "ok"
    Set-StepStatus 3 "done"
    Set-Progress 4
}

# ── SHARED STEP STATE ─────────────────────────────────────────────────────────
$script:jwt         = $null
$script:machineUuid = $null
$script:machineName = $null

# ── MAIN EXECUTION ────────────────────────────────────────────────────────────
$form.Show()
DoEvents

try {
    Step-Authenticate
    Step-DetectUUID
    Step-DetectHostname
    Step-RegisterMachine

    Add-Log "" "normal"
    Add-Log "══════════════════════════════════════════════" "ok"
    Add-Log "  Machine registered successfully!" "ok"
    Add-Log "══════════════════════════════════════════════" "ok"
    Add-Log "" "normal"
    Add-Log "  UUID:     $($script:machineUuid)" "info"
    Add-Log "  Machine:  $($script:machineName)" "info"
    Add-Log "" "normal"
    Add-Log "  Next step:" "normal"
    Add-Log "  Go to the dashboard in your browser and" "normal"
    Add-Log "  download the installer for this machine:" "normal"
    Add-Log "" "normal"
    Add-Log "  $ApiBaseUrl" "info"
    Add-Log "" "normal"
    Set-Status "Registration complete. Visit the dashboard to download your installer."
}
catch {
    $errMsg = $_.Exception.Message
    Add-Log "" "normal"
    Add-Log "Setup failed: $errMsg" "err"
    Set-Status "Setup failed. Review the log above, then close this window."
    # Form stays open so the user can read the error message.
}
finally {
    # Always attempt to revoke the setup token, even on failure or early exit.
    try {
        Invoke-Post "/setup/revoke" @{ setupToken = $SetupToken } | Out-Null
    }
    catch { }
}

# Keep event loop running until user closes the window.
while ($form.Visible) {
    DoEvents
    [System.Threading.Thread]::Sleep(50)
}
    Set-StepStatus 4 "running"
    Set-Status "Building installer — this may take several minutes..."
    Add-Log "-> Starting installer build for UUID $($script:machineUuid)..." "info"
    Add-Log "" "normal"

    $client = [System.Net.Http.HttpClient]::new()
    $client.Timeout = [System.TimeSpan]::FromHours(2)
    $client.DefaultRequestHeaders.Authorization =
        [System.Net.Http.Headers.AuthenticationHeaderValue]::new("Bearer", $script:jwt)
    $client.DefaultRequestHeaders.Accept.Add(
        [System.Net.Http.Headers.MediaTypeWithQualityHeaderValue]::new("text/event-stream"))

    $encodedUUID = [System.Uri]::EscapeDataString($script:machineUuid)

    $resp = $client.GetAsync(
        "$ApiBaseUrl/generate/$encodedUUID",
        [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead
    ).GetAwaiter().GetResult()

    if (-not $resp.IsSuccessStatusCode) {
        $body = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $client.Dispose()
        $msg = "Build request failed (HTTP $([int]$resp.StatusCode))"
        try { $j = $body | ConvertFrom-Json; if ($j.message) { $msg = $j.message } } catch { }
        throw $msg
    }

    $stream = $resp.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
    $reader = [System.IO.StreamReader]::new($stream)
    $buildDone = $false

    try {
        while (-not $reader.EndOfStream -and -not $buildDone) {
            if (-not $form.Visible) { throw "Setup window was closed." }

            # Non-blocking async read so DoEvents() keeps the form responsive
            $readTask = $reader.ReadLineAsync()
            while (-not $readTask.IsCompleted) {
                DoEvents
                [System.Threading.Thread]::Sleep(20)
                if (-not $form.Visible) { throw "Setup window was closed." }
            }
            $line = $readTask.GetAwaiter().GetResult()
            if ($null -eq $line) { break }

            if ($line.StartsWith("data: ")) {
                $data = $line.Substring(6).Trim()
                try {
                    $evt   = $data | ConvertFrom-Json
                    $inner = if ($evt.PSObject.Properties["data"] -and $evt.data -is [psobject]) {
                                 $evt.data
                             } else { $evt }

                    switch ($inner.type) {
                        "complete" {
                            Add-Log "   $($inner.message)" "ok"
                            $buildDone = $true
                        }
                        "error"  { throw [string]$inner.message }
                        "stderr" { Add-Log "   $($inner.message)" "warn" }
                        default  { Add-Log "   $($inner.message)" "normal" }
                    }
                }
                catch [System.Management.Automation.RuntimeException] { throw }
                catch { }  # skip malformed SSE frames
            }
        }
    }
    finally {
        $reader.Dispose()
        $client.Dispose()
    }

    if (-not $buildDone) {
        throw "Build stream ended without a completion signal. The build may have failed on the server."
    }

    Add-Log "" "normal"
    Set-StepStatus 4 "done"
    Set-Progress 5
}

function Step-DownloadInstaller {
    Set-StepStatus 5 "running"
    Set-Status "Downloading installer..."
    Add-Log "-> Downloading installer from server..." "info"

    $client = [System.Net.Http.HttpClient]::new()
    $client.Timeout = [System.TimeSpan]::FromHours(1)
    $client.DefaultRequestHeaders.Authorization =
        [System.Net.Http.Headers.AuthenticationHeaderValue]::new("Bearer", $script:jwt)

    $encodedUUID = [System.Uri]::EscapeDataString($script:machineUuid)

    $resp = $client.GetAsync(
        "$ApiBaseUrl/download/$encodedUUID",
        [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead
    ).GetAwaiter().GetResult()

    if (-not $resp.IsSuccessStatusCode) {
        $client.Dispose()
        throw "Download failed: HTTP $([int]$resp.StatusCode)"
    }

    # Extract filename from Content-Disposition header
    $cd       = $resp.Content.Headers.ContentDisposition
    $filename = if ($cd -and $cd.FileName) {
                    $cd.FileName.Trim('"').Trim("'")
                } else {
                    "inventory_$($script:machineUuid)_setup.exe"
                }
    $destPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), $filename)

    $totalBytes = $resp.Content.Headers.ContentLength
    $stream     = $resp.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
    $fileStream = [System.IO.FileStream]::new($destPath, [System.IO.FileMode]::Create)

    try {
        $buffer    = New-Object byte[] 65536
        $totalRead = [long]0
        $bytesRead = 0

        while (($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fileStream.Write($buffer, 0, $bytesRead)
            $totalRead += $bytesRead
            $kb = [Math]::Round($totalRead / 1KB)
            if ($totalBytes -gt 0) {
                $pct = [int]($totalRead / $totalBytes * 100)
                Set-Status "Downloading installer... $pct% ($kb KB / $([Math]::Round($totalBytes / 1KB)) KB)"
            }
            else {
                Set-Status "Downloading installer... $kb KB"
            }
            DoEvents
        }
    }
    finally {
        $fileStream.Dispose()
        $stream.Dispose()
        $client.Dispose()
    }

    $script:installerPath = $destPath
    Add-Log "   Downloaded: $filename" "ok"
    Set-StepStatus 5 "done"
    Set-Progress 6
    Set-Status "Download complete."
}

function Step-Install {
    Set-StepStatus 6 "running"
    Set-Status "Installing application — please wait..."
    Add-Log "-> Running installer silently..." "info"

    $ext  = [System.IO.Path]::GetExtension($script:installerPath).ToLower()
    $proc = $null

    if ($ext -eq ".msi") {
        $proc = Start-Process -FilePath "msiexec.exe" `
            -ArgumentList "/i `"$($script:installerPath)`" /qn /norestart" `
            -PassThru -Wait -ErrorAction Stop
    }
    else {
        # NSIS installer: /S = silent
        $proc = Start-Process -FilePath $script:installerPath `
            -ArgumentList "/S" `
            -PassThru -Wait -ErrorAction Stop
    }

    if ($proc.ExitCode -ne 0) {
        throw "Installer exited with code $($proc.ExitCode)."
    }

    Add-Log "   Application installed successfully." "ok"
    Set-StepStatus 6 "done"
    Set-Progress 7
}

function Step-Launch {
    Set-StepStatus 7 "running"
    Set-Status "Launching application..."
    Add-Log "-> Starting Inventory..." "info"

    # Check common Tauri per-user and per-machine install locations
    $candidates = @(
        [System.IO.Path]::Combine($env:LOCALAPPDATA, "inventory", "inventory.exe"),
        [System.IO.Path]::Combine($env:LOCALAPPDATA, "Programs", "inventory", "inventory.exe"),
        [System.IO.Path]::Combine($env:ProgramFiles,             "inventory", "inventory.exe"),
        [System.IO.Path]::Combine(${env:ProgramFiles(x86)},      "inventory", "inventory.exe")
    )
    $appExe = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

    if ($appExe) {
        Start-Process -FilePath $appExe -ErrorAction Stop
        Add-Log "   Application launched: $appExe" "ok"
    }
    else {
        Add-Log "   inventory.exe not found in expected locations." "warn"
        Add-Log "   Please launch the application from the Start Menu." "warn"
    }

    Set-StepStatus 7 "done"
    Set-Progress 8
}

# ── SHARED STEP STATE ─────────────────────────────────────────────────────────
$script:jwt           = $null
$script:machineUuid   = $null
$script:machineName   = $null
$script:installerPath = $null

# ── MAIN EXECUTION ────────────────────────────────────────────────────────────
$form.Show()
DoEvents

try {
    Step-Authenticate
    Step-DetectUUID
    Step-DetectHostname
    Step-RegisterMachine
    Step-BuildInstaller
    Step-DownloadInstaller
    Step-Install
    Step-Launch

    Add-Log "" "normal"
    Add-Log "======================================================" "ok"
    Add-Log "  Setup complete! Inventory is ready to use." "ok"
    Add-Log "======================================================" "ok"

    # Count down and auto-close
    $closeAt = (Get-Date).AddSeconds(6)
    while ((Get-Date) -lt $closeAt -and $form.Visible) {
        $secs = [Math]::Ceiling(($closeAt - (Get-Date)).TotalSeconds)
        Set-Status "Setup complete!  Closing in $secs seconds..."
        DoEvents
        [System.Threading.Thread]::Sleep(100)
    }
    if ($form.Visible) { $form.Close() }
}
catch {
    $errMsg = $_.Exception.Message
    Add-Log "" "normal"
    Add-Log "Setup failed: $errMsg" "err"
    Set-Status "Setup failed. Review the log above, then close this window."
    # Form stays open so the user can read the error message.
}
finally {
    # Always attempt to revoke the setup token, even on failure or early exit.
    try {
        Invoke-Post "/setup/revoke" @{ setupToken = $SetupToken } | Out-Null
    }
    catch { }
}

# Keep event loop running until user closes the window (error path / early close).
while ($form.Visible) {
    DoEvents
    [System.Threading.Thread]::Sleep(50)
}
