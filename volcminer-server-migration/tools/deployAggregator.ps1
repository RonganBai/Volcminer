param(
  [Parameter(Mandatory = $true)]
  [string]$PackagePath,

  [string]$RemoteHost = "10.0.0.52",
  [string]$User = "itsminer",
  [int]$Port = 22,
  [string]$ServiceName = "volcminer-aggregator",
  [string]$RemoteRoot = "/opt/volcminer-server-migration",
  [string]$TargetParent = "/opt",
  [string]$RemotePackagePath,
  [string]$KeyPath,
  [string]$SudoPassword,
  [switch]$SkipHealthCheck
)

$ErrorActionPreference = "Stop"

function Assert-Command {
  param([string]$Name)

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Quote-Bash {
  param([string]$Value)

  $single = [string][char]39
  $double = [string][char]34
  $replacement = $single + $double + $single + $double + $single
  return $single + $Value.Replace($single, $replacement) + $single
}

function ConvertTo-PlainText {
  param([Security.SecureString]$SecureValue)

  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
  }
}

Assert-Command ssh
Assert-Command scp

$resolvedPackage = (Resolve-Path $PackagePath).Path
if (-not (Test-Path $resolvedPackage -PathType Leaf)) {
  throw "Package not found: $PackagePath"
}

if (-not $RemotePackagePath) {
  $RemotePackagePath = "/home/$User/" + [IO.Path]::GetFileName($resolvedPackage)
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = "$RemoteRoot.bak-$timestamp"
$sshTarget = "$User@$RemoteHost"
$packageName = [IO.Path]::GetFileName($resolvedPackage)
$sudoProbeDir = "/tmp/itsminer-codex-sudo-probe-$timestamp"

$scpArgs = @()
$sshArgs = @()

if ($Port -gt 0) {
  $scpArgs += @("-P", "$Port")
  $sshArgs += @("-p", "$Port")
}

if ($KeyPath) {
  $resolvedKeyPath = (Resolve-Path $KeyPath).Path
  $scpArgs += @("-i", $resolvedKeyPath)
  $sshArgs += @("-i", $resolvedKeyPath)
}

$sudoIsPasswordless = $false
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& ssh @sshArgs $sshTarget "sudo -n /usr/bin/systemctl status $(Quote-Bash $ServiceName) > /dev/null 2>&1" 1>$null 2>$null
$ErrorActionPreference = $previousErrorActionPreference
if ($LASTEXITCODE -eq 0) {
  $sudoIsPasswordless = $true
}

if (-not $sudoIsPasswordless) {
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  & ssh @sshArgs $sshTarget "sudo -n /usr/bin/mkdir -p $(Quote-Bash $sudoProbeDir) && sudo -n /usr/bin/rm -rf $(Quote-Bash $sudoProbeDir)" 1>$null 2>$null
  $ErrorActionPreference = $previousErrorActionPreference
  if ($LASTEXITCODE -eq 0) {
    $sudoIsPasswordless = $true
  }
}

if ($sudoIsPasswordless) {
  Write-Host "Detected passwordless sudo on $sshTarget."
}

if ($PSBoundParameters.ContainsKey("SudoPassword")) {
  $sudoIsPasswordless = $false
}

if (-not $sudoIsPasswordless -and -not $PSBoundParameters.ContainsKey("SudoPassword")) {
  $secure = Read-Host "Sudo password for $User@$RemoteHost (leave blank to let sudo prompt remotely once)" -AsSecureString
  if ($secure.Length -gt 0) {
    $SudoPassword = ConvertTo-PlainText $secure
  }
}

Write-Host "Uploading package $packageName to $sshTarget ..."
& scp @scpArgs $resolvedPackage "${sshTarget}:$RemotePackagePath"
if ($LASTEXITCODE -ne 0) {
  throw "scp upload failed with exit code $LASTEXITCODE"
}

$sudoPrefix = if ($sudoIsPasswordless) {
  "sudo -n"
} elseif ($SudoPassword) {
  "printf '%s\n' $(Quote-Bash $SudoPassword) | sudo -S -p ''"
} else {
  "sudo"
}

$healthCheck = if ($SkipHealthCheck) {
  ""
} else {
  @"
health_ok=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if curl --fail --silent --show-error http://127.0.0.1:18080/health; then
    echo
    health_ok=1
    break
  fi
  sleep 2
done
if [ "$health_ok" -ne 1 ]; then
  echo "Health check failed for $(Quote-Bash $ServiceName) on port 18080" >&2
  exit 1
fi
if ! sudo -n /usr/bin/systemctl status $(Quote-Bash $ServiceName) | head -n 20; then
  echo "Warning: unable to print systemctl status without sudo password; service health check already passed." >&2
fi
"@
}

$remoteScript = @"
set -euo pipefail
$sudoPrefix /usr/bin/systemctl stop $(Quote-Bash $ServiceName)
if [ -d $(Quote-Bash $RemoteRoot) ]; then
  $sudoPrefix /usr/bin/mv $(Quote-Bash $RemoteRoot) $(Quote-Bash $backupDir)
fi
$sudoPrefix /usr/bin/mkdir -p $(Quote-Bash $RemoteRoot)
$sudoPrefix /usr/bin/tar -xzf $(Quote-Bash $RemotePackagePath) -C $(Quote-Bash $RemoteRoot)
if [ -f $(Quote-Bash "$backupDir/.env") ]; then
  $sudoPrefix /usr/bin/cp $(Quote-Bash "$backupDir/.env") $(Quote-Bash "$RemoteRoot/.env")
fi
if [ -f $(Quote-Bash "$backupDir/config/miners.json") ]; then
  $sudoPrefix /usr/bin/mkdir -p $(Quote-Bash "$RemoteRoot/config")
  $sudoPrefix /usr/bin/cp $(Quote-Bash "$backupDir/config/miners.json") $(Quote-Bash "$RemoteRoot/config/miners.json")
fi
if [ -f $(Quote-Bash "$backupDir/data/settings.json") ]; then
  $sudoPrefix /usr/bin/mkdir -p $(Quote-Bash "$RemoteRoot/data")
  $sudoPrefix /usr/bin/cp $(Quote-Bash "$backupDir/data/settings.json") $(Quote-Bash "$RemoteRoot/data/settings.json")
fi
if [ -f $(Quote-Bash "$backupDir/data/cache.json") ]; then
  $sudoPrefix /usr/bin/mkdir -p $(Quote-Bash "$RemoteRoot/data")
  $sudoPrefix /usr/bin/cp $(Quote-Bash "$backupDir/data/cache.json") $(Quote-Bash "$RemoteRoot/data/cache.json")
fi
if [ ! -f $(Quote-Bash "$RemoteRoot/.env") ]; then
  echo "Missing required environment file: $RemoteRoot/.env" >&2
  echo "Deployment aborted before service start. Restore .env into backup or target directory and retry." >&2
  exit 1
fi
$sudoPrefix /usr/bin/chown -R www-data:www-data $(Quote-Bash $RemoteRoot)
$sudoPrefix /usr/bin/systemctl start $(Quote-Bash $ServiceName)
$sudoPrefix /usr/bin/rm -f $(Quote-Bash $RemotePackagePath)
$healthCheck
"@

Write-Host "Deploying on server and restoring persisted files ..."
& ssh @sshArgs $sshTarget $remoteScript
if ($LASTEXITCODE -ne 0) {
  throw "ssh deploy failed with exit code $LASTEXITCODE"
}

Write-Host "Deployment finished successfully."
