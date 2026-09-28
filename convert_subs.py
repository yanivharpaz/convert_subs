#!/usr/bin/env python3

import argparse
import codecs
import os
import shutil
import stat
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import TextIO


DEFAULT_SOURCE_ENCODING = "windows-1255"
SUBTITLE_EXTENSIONS = {".srt", ".sub"}


@dataclass
class ConversionStats:
    converted: int = 0
    skipped: int = 0
    failed: int = 0


def _is_utf8(data: bytes) -> bool:
    try:
        data.decode("utf-8")
    except UnicodeDecodeError:
        return False
    return True


def _convert_file(path: Path, source_encoding: str) -> str:
    original = path.read_bytes()
    if _is_utf8(original):
        return "skipped"

    backup = Path(f"{path}.bak")
    if backup.exists():
        raise FileExistsError(f"backup already exists: {backup}")

    converted = original.decode(source_encoding).encode("utf-8")
    file_mode = stat.S_IMODE(path.stat().st_mode)
    temp_path = None

    try:
        with tempfile.NamedTemporaryFile(
            mode="wb",
            dir=str(path.parent),
            prefix=f".{path.name}.",
            suffix=".tmp",
            delete=False,
        ) as temp_file:
            temp_path = Path(temp_file.name)
            temp_file.write(converted)
            temp_file.flush()
            os.fsync(temp_file.fileno())

        shutil.copy2(path, backup)
        os.chmod(temp_path, file_mode)
        os.replace(temp_path, path)
    finally:
        if temp_path is not None and temp_path.exists():
            temp_path.unlink()

    return "converted"


def convert_directory(
    directory: Path,
    source_encoding: str = DEFAULT_SOURCE_ENCODING,
    stdout: TextIO = sys.stdout,
    stderr: TextIO = sys.stderr,
) -> ConversionStats:
    codecs.lookup(source_encoding)
    stats = ConversionStats()

    subtitle_files = sorted(
        path
        for path in directory.iterdir()
        if path.is_file()
        and not path.name.startswith("._")
        and path.suffix.lower() in SUBTITLE_EXTENSIONS
    )

    for path in subtitle_files:
        try:
            result = _convert_file(path, source_encoding)
        except (OSError, UnicodeError) as error:
            print(f"Error: could not convert {path}: {error}", file=stderr)
            stats.failed += 1
            continue

        if result == "skipped":
            print(f"Skipping already UTF-8: {path}", file=stdout)
            stats.skipped += 1
        else:
            print(f"Converted: {path} (backup: {path}.bak)", file=stdout)
            stats.converted += 1

    print(
        f"\nDone: {stats.converted} converted, "
        f"{stats.skipped} skipped, {stats.failed} failed.",
        file=stdout,
    )
    return stats


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Convert .srt and .sub files in the current directory to UTF-8."
        )
    )
    parser.add_argument(
        "source_encoding",
        nargs="?",
        default=DEFAULT_SOURCE_ENCODING,
        help="source encoding (default: windows-1255)",
    )
    return parser


def main() -> int:
    args = _build_parser().parse_args()
    try:
        stats = convert_directory(Path.cwd(), args.source_encoding)
    except LookupError:
        print(f"Error: unknown source encoding: {args.source_encoding}", file=sys.stderr)
        return 2
    except OSError as error:
        print(f"Error: could not scan {Path.cwd()}: {error}", file=sys.stderr)
        return 1
    return 1 if stats.failed else 0


if __name__ == "__main__":
    sys.exit(main())
