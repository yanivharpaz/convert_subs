import io
import tempfile
import unittest
from pathlib import Path

from convert_subs import convert_directory


class ConvertDirectoryTests(unittest.TestCase):
    def setUp(self):
        self.temp_directory = tempfile.TemporaryDirectory()
        self.directory = Path(self.temp_directory.name)
        self.stdout = io.StringIO()
        self.stderr = io.StringIO()

    def tearDown(self):
        self.temp_directory.cleanup()

    def convert(self, source_encoding="windows-1255"):
        return convert_directory(
            self.directory,
            source_encoding,
            stdout=self.stdout,
            stderr=self.stderr,
        )

    def test_converts_windows_1255_and_preserves_original_as_backup(self):
        subtitle = self.directory / "Hebrew subtitle.srt"
        original = "שלום עולם\n".encode("windows-1255")
        subtitle.write_bytes(original)
        subtitle.chmod(0o640)

        stats = self.convert()

        self.assertEqual((stats.converted, stats.skipped, stats.failed), (1, 0, 0))
        self.assertEqual(subtitle.read_text(encoding="utf-8"), "שלום עולם\n")
        self.assertEqual(Path(f"{subtitle}.bak").read_bytes(), original)
        self.assertEqual(subtitle.stat().st_mode & 0o777, 0o640)
        self.assertEqual(self.stderr.getvalue(), "")

    def test_skips_files_that_are_already_utf8(self):
        subtitle = self.directory / "already-utf8.sub"
        subtitle.write_text("שלום\n", encoding="utf-8")

        stats = self.convert()

        self.assertEqual((stats.converted, stats.skipped, stats.failed), (0, 1, 0))
        self.assertFalse(Path(f"{subtitle}.bak").exists())
        self.assertIn("Skipping already UTF-8", self.stdout.getvalue())

    def test_ignores_appledouble_non_subtitle_and_nested_files(self):
        apple_double = self.directory / "._Episode.srt"
        apple_double.write_bytes(b"\x00metadata")
        (self.directory / "movie.mkv").write_bytes(b"\xff")
        nested = self.directory / "nested"
        nested.mkdir()
        (nested / "Episode.srt").write_bytes("שלום".encode("windows-1255"))

        stats = self.convert()

        self.assertEqual((stats.converted, stats.skipped, stats.failed), (0, 0, 0))
        self.assertEqual(apple_double.read_bytes(), b"\x00metadata")
        self.assertFalse(Path(f"{apple_double}.bak").exists())

    def test_handles_uppercase_extension_and_spaces(self):
        subtitle = self.directory / "Episode Name.SUB"
        subtitle.write_bytes("כתובית".encode("windows-1255"))

        stats = self.convert()

        self.assertEqual((stats.converted, stats.skipped, stats.failed), (1, 0, 0))
        self.assertEqual(subtitle.read_text(encoding="utf-8"), "כתובית")

    def test_existing_backup_fails_without_changing_original(self):
        subtitle = self.directory / "Episode.srt"
        original = "שלום".encode("windows-1255")
        subtitle.write_bytes(original)
        backup = Path(f"{subtitle}.bak")
        backup.write_bytes(b"existing backup")

        stats = self.convert()

        self.assertEqual((stats.converted, stats.skipped, stats.failed), (0, 0, 1))
        self.assertEqual(subtitle.read_bytes(), original)
        self.assertEqual(backup.read_bytes(), b"existing backup")
        self.assertIn("backup already exists", self.stderr.getvalue())

    def test_invalid_source_bytes_fail_without_creating_backup(self):
        subtitle = self.directory / "Episode.srt"
        original = b"\xff"
        subtitle.write_bytes(original)

        stats = self.convert("ascii")

        self.assertEqual((stats.converted, stats.skipped, stats.failed), (0, 0, 1))
        self.assertEqual(subtitle.read_bytes(), original)
        self.assertFalse(Path(f"{subtitle}.bak").exists())
        self.assertIn("could not convert", self.stderr.getvalue())

    def test_unknown_source_encoding_is_rejected(self):
        with self.assertRaises(LookupError):
            self.convert("not-a-real-encoding")


if __name__ == "__main__":
    unittest.main()
