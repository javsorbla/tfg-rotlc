param(
    [string]$ExperimentName = "umbra_autogate",
    [int]$TotalSteps = 150000,
    [int]$BlockSteps = 5000,
    [double]$LearningRate = 0.0001,
    [int]$NSteps = 1024,
    [int]$BatchSize = 256,
    [int]$NEpochs = 10,
    [double]$TargetKl = 0.015,
    [double]$Gamma = 0.995,
    [double]$GaeLambda = 0.95,
    [string]$CheckpointDir = "",
    [string]$OnnxOut = "Juego/umbra.onnx",
    [string]$PythonExe = ".venv/Scripts/python.exe",
    [double]$GateMaxDominant = 0.85,
        [double]$GateMinLrAcc = 0.55,
        [double]$GateLrDeadzone = 0.07,
    [double]$EntCoef = 0.03
)

$ErrorActionPreference = "Stop"

function Join-ArgsForProcess {
    param(
        [string[]]$Arguments
    )

    return ($Arguments | ForEach-Object {
        if ($_ -match '[\s"]') {
            '"' + ($_ -replace '"', '\"') + '"'
        }
        else {
            $_
        }
    }) -join ' '
}

function Invoke-ExternalProcess {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = Join-ArgsForProcess -Arguments $Arguments
    # Avoid UnicodeEncodeError from Python tools emitting non-cp1252 characters.
    $psi.EnvironmentVariables["PYTHONUTF8"] = "1"
    $psi.EnvironmentVariables["PYTHONIOENCODING"] = "utf-8"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    [void]$process.Start()

    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    return [PSCustomObject]@{
        ExitCode = $process.ExitCode
        StdOut = $stdout
        StdErr = $stderr
    }
}

function Write-ProcessOutput {
    param(
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return
    }

    $Text.TrimEnd("`r", "`n").Split("`n") | ForEach-Object {
        Write-Host $_.TrimEnd("`r")
    }
}

if (-not (Test-Path $PythonExe)) {
    throw "Python executable not found at '$PythonExe'."
}

$repoRoot = Get-Location
if ([string]::IsNullOrWhiteSpace($CheckpointDir)) {
    $CheckpointDir = "logs/sb3/${ExperimentName}_checkpoints"
}

$trainedSteps = 0
$resumeZip = $null
$foundHealthy = $false
$pausedForGodot = $false

if ([string]::IsNullOrWhiteSpace($CheckpointDir) -eq $false -and (Test-Path $CheckpointDir)) {
    $latestExisting = Get-ChildItem -Path $CheckpointDir -Filter "*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -ne $latestExisting) {
        $resumeZip = $latestExisting.FullName
        Write-Host "[AUTOGATE] Resuming from latest checkpoint: $resumeZip"
        if ($latestExisting.BaseName -match '_(\d+)_steps$') {
            $trainedSteps = [int]$Matches[1]
            Write-Host "[AUTOGATE] Detected progress from checkpoint: $trainedSteps steps"
        }
    }
}

Write-Host "[AUTOGATE] Experiment=$ExperimentName TotalSteps=$TotalSteps BlockSteps=$BlockSteps"
Write-Host "[AUTOGATE] CheckpointDir=$CheckpointDir"
Write-Host "[AUTOGATE] ONNX target=$OnnxOut"

while ($trainedSteps -lt $TotalSteps -and -not $foundHealthy) {
    $remaining = $TotalSteps - $trainedSteps
    $thisBlock = [Math]::Min($BlockSteps, $remaining)

    Write-Host "[AUTOGATE] Training block: +$thisBlock steps (progress $trainedSteps/$TotalSteps)"

    $args = @(
        "stable_baselines3_example.py",
        "--experiment_name=$ExperimentName",
        "--experiment_dir=logs/sb3",
        "--timesteps=$thisBlock",
        "--save_checkpoint_frequency=$BlockSteps",
        "--learning_rate=$LearningRate",
        "--ent_coef=$EntCoef",
        "--n_steps=$NSteps",
        "--batch_size=$BatchSize",
        "--n_epochs=$NEpochs",
        "--gamma=$Gamma",
        "--gae_lambda=$GaeLambda",
        "--target_kl=$TargetKl"
    )

    if ($null -ne $resumeZip) {
        $args += "--resume_model_path=$resumeZip"
    }

    $trainingResult = Invoke-ExternalProcess -FilePath $PythonExe -Arguments $args
    Write-ProcessOutput -Text $trainingResult.StdOut
    Write-ProcessOutput -Text $trainingResult.StdErr

    $trainingCombined = "$($trainingResult.StdOut)`n$($trainingResult.StdErr)"
    $sawPlayPrompt = $trainingCombined -match 'No game binary has been provided, please press PLAY in the Godot editor'
    $sawConnectionEstablished = $trainingCombined -match 'connection established'
    $sawTrainingProgress = $trainingCombined -match 'total_timesteps\s*\|'
    if ($sawPlayPrompt -and -not $sawConnectionEstablished -and -not $sawTrainingProgress) {
        $latestAfterBlock = Get-ChildItem -Path $CheckpointDir -Filter "*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($null -ne $latestAfterBlock) {
            $resumeZip = $latestAfterBlock.FullName
        }
        $pausedForGodot = $true
        Write-Host "[AUTOGATE] Godot stopped after completing the current block. Press PLAY again and rerun the same command to continue."
        break
    }
    if ($trainingResult.ExitCode -ne 0) {
        throw "Training block failed with exit code $($trainingResult.ExitCode)"
    }

    $trainedSteps += $thisBlock

    Write-Host "[AUTOGATE] Running checkpoint gate..."
    $gateArgs = @(
        "umbra_checkpoint_gate.py",
        "--checkpoint_dir=$CheckpointDir",
        "--max-dominant=$GateMaxDominant",
        "--min-lr-acc=$GateMinLrAcc",
        "--lr-deadzone=$GateLrDeadzone",
        "--export-onnx=$OnnxOut"
    )

    $gateResult = Invoke-ExternalProcess -FilePath $PythonExe -Arguments $gateArgs
    Write-ProcessOutput -Text $gateResult.StdOut
    Write-ProcessOutput -Text $gateResult.StdErr

    if ($gateResult.ExitCode -ne 0) {
        throw "Checkpoint gate failed with exit code $($gateResult.ExitCode)"
    }

    if (Test-Path $OnnxOut) {
        $lastWrite = (Get-Item $OnnxOut).LastWriteTime
        # Consider success when ONNX exists and was touched in this loop execution window.
        if ($lastWrite -gt (Get-Date).AddMinutes(-10)) {
            $foundHealthy = $true
            Write-Host "[AUTOGATE] Healthy checkpoint found and exported: $OnnxOut"
            break
        }
    }

    $latest = Get-ChildItem -Path $CheckpointDir -Filter "*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $latest) {
        throw "No checkpoint zip found in '$CheckpointDir' after training block."
    }
    $resumeZip = $latest.FullName
    Write-Host "[AUTOGATE] No healthy checkpoint yet. Next resume: $resumeZip"
}

if (-not $foundHealthy) {
    if ($pausedForGodot) {
        Write-Host "[AUTOGATE] Paused cleanly. Latest checkpoint preserved at: $resumeZip"
        exit 0
    }

    Write-Host "[AUTOGATE] Finished $trainedSteps steps without healthy checkpoint under current thresholds."
    Write-Host "[AUTOGATE] Try relaxing thresholds or increasing exploration (ent_coef) and rerun."
    exit 2
}

Write-Host "[AUTOGATE] Done. ONNX ready at $OnnxOut"
exit 0
