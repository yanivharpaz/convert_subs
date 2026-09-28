#!/usr/bin/env pwsh

param(
    [Parameter(Position = 0)]
    [string] $SourceEncoding = "windows-1255"
)

Set-StrictMode -Version Latest

function Get-SubtitleEncoding {
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    [Text.Encoding]::RegisterProvider([Text.CodePagesEncodingProvider]::Instance)
    return [Text.Encoding]::GetEncoding(
        $Name,
        [Text.EncoderFallback]::ExceptionFallback,
        [Text.DecoderFallback]::ExceptionFallback
    )
}

function Invoke-SubtitleConversion {
    param(
        [string] $Directory = (Get-Location).Path,
        [string] $Encoding = "windows-1255"
    )

    $source = Get-SubtitleEncoding -Name $Encoding
    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    $stats = [pscustomobject]@{
        Converted = 0
        Skipped   = 0
        Failed    = 0
    }

    $files = Get-ChildItem -LiteralPath $Directory -File |
        Where-Object {
            -not $_.Name.StartsWith("._") -and
            $_.Extension.ToLowerInvariant() -in ".srt", ".sub"
        } |
        Sort-Object -Property FullName

    foreach ($file in $files) {
        $tempPath = $null

        try {
            $original = [IO.File]::ReadAllBytes($file.FullName)
            try {
                $null = $utf8.GetString($original)
                [Console]::WriteLine("Skipping already UTF-8: {0}", $file.FullName)
                $stats.Skipped++
                continue
            }
            catch [Text.DecoderFallbackException] {
                # Continue with conversion from the requested source encoding.
            }

            $backupPath = "$($file.FullName).bak"
            if (Test-Path -LiteralPath $backupPath) {
                throw [IO.IOException]::new(
                    "backup already exists: $backupPath"
                )
            }

            $converted = $utf8.GetBytes($source.GetString($original))
            $tempName = ".{0}.{1}.tmp" -f $file.Name, [IO.Path]::GetRandomFileName()
            $tempPath = Join-Path -Path $file.DirectoryName -ChildPath $tempName
            [IO.File]::WriteAllBytes($tempPath, $converted)

            if (-not $IsWindows) {
                $mode = [IO.File]::GetUnixFileMode($file.FullName)
                [IO.File]::SetUnixFileMode($tempPath, $mode)
            }

            Copy-Item -LiteralPath $file.FullName -Destination $backupPath -ErrorAction Stop
            [IO.File]::Move($tempPath, $file.FullName, $true)
            $tempPath = $null

            [Console]::WriteLine(
                "Converted: {0} (backup: {1})",
                $file.FullName,
                $backupPath
            )
            $stats.Converted++
        }
        catch {
            [Console]::Error.WriteLine(
                "Error: could not convert {0}: {1}",
                $file.FullName,
                $_.Exception.Message
            )
            $stats.Failed++
        }
        finally {
            if ($null -ne $tempPath -and (Test-Path -LiteralPath $tempPath)) {
                Remove-Item -LiteralPath $tempPath -Force
            }
        }
    }

    [Console]::WriteLine(
        "`nDone: {0} converted, {1} skipped, {2} failed.",
        $stats.Converted,
        $stats.Skipped,
        $stats.Failed
    )
    return $stats
}

if ($MyInvocation.InvocationName -ne ".") {
    try {
        $result = Invoke-SubtitleConversion -Encoding $SourceEncoding
    }
    catch {
        [Console]::Error.WriteLine("Error: {0}", $_.Exception.Message)
        exit 2
    }

    if ($result.Failed -gt 0) {
        exit 1
    }
}
