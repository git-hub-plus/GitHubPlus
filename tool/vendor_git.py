"""Puts a portable Git for Windows (MinGit + git-lfs) into third_party/git.

GitHub+ runs git as a child process. Shipping our own copy keeps behaviour
identical on every PC (users may not have Git installed). The folder is
git-ignored; the Windows build copies it next to the executable.

Sources, in order:
  1. --from <dir>        an existing portable git folder (has cmd/git.exe)
  2. the dugite copy used by the Electron version (../GitHub+/node_modules/dugite/git)
  3. download of the dugite-native release archive (DUGITE_NATIVE_URL)

Usage: python tool/vendor_git.py [--from <dir>]
"""

import argparse
import shutil
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGET = ROOT / "third_party" / "git"
ELECTRON_COPY = ROOT.parent / "GitHub+" / "node_modules" / "dugite" / "git"
DUGITE_NATIVE_URL = (
    "https://github.com/desktop/dugite-native/releases/download/"
    "v2.47.1/dugite-native-v2.47.1-7d4c9ea-windows-x64.tar.gz"
)


def is_git_dir(path: Path) -> bool:
    return (path / "cmd" / "git.exe").is_file()


def download(target: Path) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        archive = Path(tmp) / "git.tar.gz"
        print(f"downloading {DUGITE_NATIVE_URL}")
        urllib.request.urlretrieve(DUGITE_NATIVE_URL, archive)
        with tarfile.open(archive) as tar:
            tar.extractall(target, filter="data")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--from", dest="source", type=Path)
    args = parser.parse_args()

    if TARGET.exists():
        shutil.rmtree(TARGET)
    TARGET.parent.mkdir(parents=True, exist_ok=True)

    source = args.source or (ELECTRON_COPY if is_git_dir(ELECTRON_COPY) else None)
    if source:
        if not is_git_dir(source):
            sys.exit(f"{source} does not contain cmd/git.exe")
        print(f"copying {source}")
        shutil.copytree(source, TARGET)
    else:
        download(TARGET)

    if not is_git_dir(TARGET):
        sys.exit("vendored git is incomplete")
    print(f"git ready in {TARGET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
