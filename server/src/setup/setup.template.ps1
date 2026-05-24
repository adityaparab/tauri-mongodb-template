# â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
# â•‘            Inventory â€” Automated Machine Setup Script                        â•‘
# â•‘  Generated for your account. Do not share this file â€” it contains a         â•‘
# â•‘  single-use credential tied to your login session.                           â•‘
# â•‘                                                                              â•‘
# â•‘  Run with:  Right-click â†’ "Run with PowerShell"                              â•‘
# â•‘         or: powershell -ExecutionPolicy Bypass -File "machine-setup.ps1"     â•‘
# â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

# â”€â”€ INJECTED CONFIGURATION (populated by the server at download time) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
$ApiBaseUrl = "__API_BASE_URL__"
$SetupToken = "__SETUP_TOKEN__"
# â”€â”€ END CONFIGURATION â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

$ErrorActionPreference = 'Stop'

# â”€â”€ ASSEMBLIES â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# â”€â”€ COLOUR PALETTE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

# â”€â”€ FONTS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
$F_TITLE    = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$F_SUB      = New-Object System.Drawing.Font("Segoe UI", 9)
$F_STEP     = New-Object System.Drawing.Font("Segoe UI", 9)
$F_STEP_ACT = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$F_ICON     = New-Object System.Drawing.Font("Segoe UI Symbol", 11)
$F_LOG      = New-Object System.Drawing.Font("Consolas", 9)

# â”€â”€ FORM â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
$form = New-Object System.Windows.Forms.Form
$form.Text            = "Inventory â€” Machine Setup"
$form.ClientSize      = New-Object System.Drawing.Size(820, 548)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox     = $false
$form.BackColor       = $C_FORM
$form.ForeColor       = $C_TEXT
$form.Icon            = [System.Drawing.SystemIcons]::Application

# â”€â”€ HEADER (58 px) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
$pnlHeader           = New-Object System.Windows.Forms.Panel
$pnlHeader.Dock      = "Top"
$pnlHeader.Height    = 58
$pnlHeader.BackColor = $C_HEADER
$form.Controls.Add($pnlHeader)

$lblTitle           = New-Object System.Windows.Forms.Label
$lblTitle.Text      = "Inventory â€” Machine Setup"
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

# â”€â”€ BOTTOM BAR (52 px) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

# â”€â”€ SIDEBAR (left 260 px, between header and bottom) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

# â”€â”€ LOG PANEL (right 559 px) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

# â”€â”€ STEP ROWS (8 steps, 54 px each starting at y=14) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
    $dot.Text       = [char]0x25CB   # â—‹ (pending)
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

# â”€â”€ UI HELPERS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function DoEvents {
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-StepStatus {
    param([int]$Index, [string]$Status)
    $c = $stepCtrls[$Index]
    switch ($Status) {
        "running" {
            $c.Dot.ForeColor   = $C_RUNNING
            $c.Dot.Text        = [char]0x25B6  # â–¶
            $c.Label.ForeColor = [System.Drawing.Color]::White
            $c.Label.Font      = $F_STEP_ACT
        }
        "done" {
            $c.Dot.ForeColor   = $C_DONE
            $c.Dot.Text        = [char]0x2713  # âœ“
            $c.Label.ForeColor = $C_TEXT
            $c.Label.Font      = $F_STEP
        }
        "failed" {
            $c.Dot.ForeColor   = $C_FAIL
            $c.Dot.Text        = [char]0x2717  # âœ—
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

# â”€â”€ API HELPERS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

# â”€â”€ STEP FUNCTIONS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

# â”€â”€ SHARED STEP STATE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
$script:jwt         = $null
$script:machineUuid = $null
$script:machineName = $null

# â”€â”€ MAIN EXECUTION â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
$form.Show()
DoEvents

try {
    Step-Authenticate
    Step-DetectUUID
    Step-DetectHostname
    Step-RegisterMachine

    Add-Log "" "normal"
    Add-Log "â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•" "ok"
    Add-Log "  Machine registered successfully!" "ok"
    Add-Log "â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•" "ok"
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
