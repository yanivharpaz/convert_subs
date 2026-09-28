#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot ".." "convert_subs.ps1")

$script:failed = 0

function Assert-Equal {
    param(
        $Expected,
        $Actual,
        [string] $Message
    )

    if ($Expected -ne $Actual) {
        throw "$Message. Expected '$Expected', got '$Actual'."
    }
}

function Assert-BytesEqual {
    param(
        [byte[]] $Expected,
        [byte[]] $Actual,
        [string] $Message
    )

    if (-not [Linq.Enumerable]::SequenceEqual($Expected, $Actual)) {
        throw $Message
    }
}

function Invoke-Test {
    param(
        [string] $Name,
        [scriptblock] $Test
    )

    $directory = Join-Path ([IO.Path]::GetTempPath()) (
        "convert_subs_pwsh_{0}" -f [Guid]::NewGuid()
    )
    [IO.Directory]::CreateDirectory($directory) | Out-Null

    try {
        & $Test $directory
        [Console]::WriteLine("PASS: {0}", $Name)
    }
    catch {
        $script:failed++
        [Console]::Error.WriteLine("FAIL: {0}: {1}", $Name, $_.Exception.Message)
    }
    finally {
        Remove-Item -LiteralPath $directory -Recurse -Force
    }
}

$windows1255 = Get-SubtitleEncoding -Name "windows-1255"
$utf8 = [Text.UTF8Encoding]::new($false, $true)

Invoke-Test "converts Windows-1255 and preserves the original backup" {
    param($directory)

    $path = Join-Path $directory "Hebrew subtitle.srt"
    $original = $windows1255.GetBytes("שלום עולם`n")
    [IO.File]::WriteAllBytes($path, $original)

    $stats = Invoke-SubtitleConversion -Directory $directory

    Assert-Equal 1 $stats.Converted "Converted count"
    Assert-Equal 0 $stats.Skipped "Skipped count"
    Assert-Equal 0 $stats.Failed "Failed count"
    Assert-Equal "שלום עולם`n" $utf8.GetString(
        [IO.File]::ReadAllBytes($path)
    ) "Converted text"
    Assert-BytesEqual $original ([IO.File]::ReadAllBytes("$path.bak")) "Backup bytes"
}

Invoke-Test "skips an existing UTF-8 subtitle" {
    param($directory)

    $path = Join-Path $directory "already-utf8.sub"
    [IO.File]::WriteAllBytes($path, $utf8.GetBytes("שלום`n"))

    $stats = Invoke-SubtitleConversion -Directory $directory

    Assert-Equal 0 $stats.Converted "Converted count"
    Assert-Equal 1 $stats.Skipped "Skipped count"
    Assert-Equal 0 $stats.Failed "Failed count"
    Assert-Equal $false (Test-Path -LiteralPath "$path.bak") "Backup existence"
}

Invoke-Test "ignores AppleDouble and unrelated files" {
    param($directory)

    $metadata = Join-Path $directory "._Episode.srt"
    [IO.File]::WriteAllBytes($metadata, [byte[]](0, 255, 1))
    [IO.File]::WriteAllBytes(
        (Join-Path $directory "Episode.mkv"),
        [byte[]](255)
    )

    $stats = Invoke-SubtitleConversion -Directory $directory

    Assert-Equal 0 $stats.Converted "Converted count"
    Assert-Equal 0 $stats.Skipped "Skipped count"
    Assert-Equal 0 $stats.Failed "Failed count"
    Assert-Equal $false (Test-Path -LiteralPath "$metadata.bak") "Backup existence"
}

Invoke-Test "handles uppercase extensions and spaces" {
    param($directory)

    $path = Join-Path $directory "Episode Name.SUB"
    [IO.File]::WriteAllBytes($path, $windows1255.GetBytes("כתובית"))

    $stats = Invoke-SubtitleConversion -Directory $directory

    Assert-Equal 1 $stats.Converted "Converted count"
    Assert-Equal "כתובית" $utf8.GetString(
        [IO.File]::ReadAllBytes($path)
    ) "Converted text"
}

Invoke-Test "does not overwrite an existing backup" {
    param($directory)

    $path = Join-Path $directory "Episode.srt"
    $original = $windows1255.GetBytes("שלום")
    [IO.File]::WriteAllBytes($path, $original)
    [IO.File]::WriteAllBytes("$path.bak", [Text.Encoding]::ASCII.GetBytes("existing"))

    $stats = Invoke-SubtitleConversion -Directory $directory

    Assert-Equal 0 $stats.Converted "Converted count"
    Assert-Equal 1 $stats.Failed "Failed count"
    Assert-BytesEqual $original ([IO.File]::ReadAllBytes($path)) "Original bytes"
    Assert-Equal "existing" ([IO.File]::ReadAllText("$path.bak")) "Backup content"
}

Invoke-Test "leaves invalid source bytes unchanged" {
    param($directory)

    $path = Join-Path $directory "Episode.srt"
    $original = [byte[]](255)
    [IO.File]::WriteAllBytes($path, $original)

    $stats = Invoke-SubtitleConversion -Directory $directory -Encoding "ascii"

    Assert-Equal 0 $stats.Converted "Converted count"
    Assert-Equal 1 $stats.Failed "Failed count"
    Assert-BytesEqual $original ([IO.File]::ReadAllBytes($path)) "Original bytes"
    Assert-Equal $false (Test-Path -LiteralPath "$path.bak") "Backup existence"
}

Invoke-Test "rejects an unknown source encoding" {
    param($directory)

    $thrown = $false
    try {
        $null = Invoke-SubtitleConversion `
            -Directory $directory `
            -Encoding "not-a-real-encoding"
    }
    catch {
        $thrown = $true
    }

    Assert-Equal $true $thrown "Unknown encoding exception"
}

if ($script:failed -gt 0) {
    [Console]::Error.WriteLine("`n{0} PowerShell test(s) failed.", $script:failed)
    exit 1
}

[Console]::WriteLine("`nAll PowerShell tests passed.")
