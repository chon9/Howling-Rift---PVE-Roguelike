param(
    [string]$GodotExe = 'K:\Godot\Godot_v4.6.3-stable_win64_console.exe',
    [switch]$Native,
    [int]$Port = 24667,
    [string]$Scene = 'tests/LanCoopTests.tscn'
)
$gameProject = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testProcesses = @()
try {
    foreach ($role in @('host','client1','client2')) {
        $testArguments = @('--path', ('"' + $gameProject + '"'), $Scene, '--', $role, '--no-steam', '--test-lan-port', "$Port")
        if (-not $Native) { $testArguments = @('--headless') + $testArguments }
        $testProcesses += Start-Process -FilePath $GodotExe -ArgumentList $testArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $PSScriptRoot ("lan-final-$role.log")) -RedirectStandardError (Join-Path $PSScriptRoot ("lan-final-$role-errors.log"))
    }
    # Retain native handles so PowerShell can read exit codes after fast exits.
    foreach ($process in $testProcesses) { $null = $process.Handle }
    Wait-Process -Id $testProcesses.Id -Timeout 45 -ErrorAction Stop
    $failed = $false
    foreach ($process in $testProcesses) {
        $process.WaitForExit()
        $process.Refresh()
        if ($process.ExitCode -ne 0) { Write-Output ("Process {0} exit code: {1}" -f $process.Id, $process.ExitCode); $failed = $true }
    }
    foreach ($role in @('host','client1','client2')) {
        Get-Content -LiteralPath (Join-Path $PSScriptRoot ("lan-final-$role.log"))
        $errors = Get-Content -LiteralPath (Join-Path $PSScriptRoot ("lan-final-$role-errors.log"))
        if ($errors) { $errors; $failed = $true }
    }
    if ($failed) { exit 1 }
    exit 0
} catch {
    foreach ($process in $testProcesses) {
        if (-not $process.HasExited) { Stop-Process -Id $process.Id }
    }
    throw
}
