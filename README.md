# convert_subs

A small macOS shell script that converts `.srt` and `.sub` subtitle files in
the current directory to UTF-8. The source encoding defaults to Windows-1255.

## Requirements

- macOS
- Bash
- `iconv` (included with macOS)

## Usage

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

The script:

- Matches `.srt` and `.sub` extensions case-insensitively.
- Ignores macOS `._*` AppleDouble metadata files on external drives.
- Keeps each original as `<filename>.bak`.
- Skips files that are already valid UTF-8.
- Handles filenames containing spaces.
- Reports how many files were converted, skipped, or failed.

Only files in the current directory are processed; subdirectories are not
searched.
