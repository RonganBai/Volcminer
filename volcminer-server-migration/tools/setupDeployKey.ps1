param(
  [string]$RemoteHost = "10.0.0.52",
  [string]$User = "itsminer",
  [int]$Port = 22,
  [string]$KeyPath = "$HOME\\.ssh\\id_ed25519"
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

Assert-Command ssh
Assert-Command ssh-keygen

$sshTarget = "$User@$RemoteHost"
$publicKeyPath = "$KeyPath.pub"

if (-not (Test-Path $KeyPath -PathType Leaf)) {
  Write-Host "Creating SSH key: $KeyPath"
  $escapedKeyPath = '"' + $KeyPath + '"'
  $commandLine = "ssh-keygen -t ed25519 -f $escapedKeyPath -N `"`""
  & cmd /c $commandLine
  if ($LASTEXITCODE -ne 0) {
    throw "ssh-keygen failed with exit code $LASTEXITCODE"
  }
}

if (-not (Test-Path $publicKeyPath -PathType Leaf)) {
  throw "Public key not found: $publicKeyPath"
}

$publicKey = (Get-Content $publicKeyPath -Raw).Trim()
$remoteCommand = @"
umask 077
mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys
grep -qxF $(Quote-Bash $publicKey) ~/.ssh/authorized_keys || echo $(Quote-Bash $publicKey) >> ~/.ssh/authorized_keys
"@

Write-Host "Installing SSH public key on $sshTarget ..."
& ssh -p $Port $sshTarget $remoteCommand
if ($LASTEXITCODE -ne 0) {
  throw "ssh key install failed with exit code $LASTEXITCODE"
}

Write-Host "SSH key install completed. Future deploys can use -KeyPath $KeyPath"
