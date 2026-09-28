# convert_subs

Shell, Python, and PowerShell scripts that convert `.srt` and `.sub` subtitle
files in the current directory to UTF-8. The source encoding defaults to
Windows-1255.

## Requirements

- Shell version: macOS, Bash, and `iconv` (included with macOS)
- Python version: Python 3.7 or newer
- PowerShell version: PowerShell 7 or newer

## Shell usage

Make the script executable:

```sh
chmod +x convert_subs.sh
```

Run it from the directory containing the subtitle files:

```sh
/path/to/convert_subs.sh
```

To use a source encoding other than Windows-1255, pass its `iconv` name:

```sh
/path/to/convert_subs.sh ISO-8859-8
```

## Python usage

Run the Python version from the directory containing the subtitle files:

```sh
python3 /path/to/convert_subs.py
```

An alternative source encoding can also be provided:

```sh
python3 /path/to/convert_subs.py ISO-8859-8
```

Run its unit tests from the repository root:

```sh
python3 -m unittest discover -s tests
```

## PowerShell usage

Run the PowerShell version from the directory containing the subtitle files:

```powershell
pwsh /path/to/convert_subs.ps1
```

An alternative source encoding can also be provided:

```powershell
pwsh /path/to/convert_subs.ps1 ISO-8859-8
```

Run its self-contained tests from the repository root:

```powershell
pwsh -NoProfile -File tests/test_convert_subs.ps1
```

All versions:

- Matches `.srt` and `.sub` extensions case-insensitively.
- Ignores macOS `._*` AppleDouble metadata files on external drives.
- Keeps each original as `<filename>.bak`.
- Skips files that are already valid UTF-8.
- Handles filenames containing spaces.
- Reports how many files were converted, skipped, or failed.

Only files in the current directory are processed; subdirectories are not
searched.
