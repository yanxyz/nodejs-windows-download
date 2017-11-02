param(
    [string]$Version = 0,
    [Alias('h')]
    [switch]$Help,
    [switch]$Online,
    [switch]$Debug
)

$dest = ".\downloads"
$url = "http://npm.taobao.org/mirrors/node"
$arch = if ([environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
$repo = "https://github.com/yanxyz/nodejs-windows-download/#readme"

#region Functions

function FetchLatest() {
    $wc = New-Object System.Net.WebClient
    $text = $wc.DownloadString("$url/latest/SHASUMS256.txt")
    if ($text -match " node-v(?<ver>[0-9\.]+)-") {
        $ver = $Matches.ver
        Write-Host "latest: $ver"
        FetchMsi $ver
    }
}

function Fetch($ver, $name) {
    $fileName = "$dest\$name"
    if (Test-Path "$fileName") {
        Write-Warning "file exists: $fileName"
        return
    }
    $src = "$url/v$ver/$name"
    Write-Debug "$src"
    # Invoke-WebRequest fails to follow HTTP redirects from HTTPS
    # https://github.com/PowerShell/PowerShell/issues/2896
    Invoke-WebRequest -Uri $src -OutFile $fileName
}

function FetchMsi($ver) {
    $name = "node-v${ver}-$arch.msi"
    Fetch $ver $name
}

# https://github.com/mafintosh/node-gyp-install
function HandleXZ($ver) {
    $name = "node-v${ver}.tar.xz"
    Fetch $ver $name
    # $7zip = "$env:ProgramFiles\7-Zip\7z.exe"
}

function ShowHelp() {
    $name = Split-Path $PSCommandPath -Leaf
    Write-Host -ForegroundColor Green @"
Usage: .\$name <version>
Download node.js Windows installer

Examples:
  .\$name 8.0.0    download v8.0.0
  .\$name 0        download the latest version

Readme: <$repo>

"@
}

#endregion

#region Process

if ($Help) {
    ShowHelp
    return
}

if ($Online) {
    Start-Process $repo
    return
}

if ($Debug) {
    $DebugPreference = "Continue"
}

mkdir $dest *> $null

if ($Version -eq "0") {
    FetchLatest
    return
}

if ($Version -match "v?(?<ver>(?<major>\d+)\.\d+\.\d+)") {
    if ([int]$Matches.major -gt 5) {
        FetchMsi $Matches.ver
    } else {
        Write-Warning "version < 6 is not supported."
    }
} else {
    Write-Warning "invalid version."
}

#endregion
