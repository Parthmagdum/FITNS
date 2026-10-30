"""Creates FITNS's permanent release signing key and hands it to GitHub Actions.

From the repository root:

    python tool/setup_release_signing.py               # key (if missing) + secrets
    python tool/setup_release_signing.py --local-only  # key only, no GitHub

It
  1. generates a keystore (default ~/keys/fitns-release.jks) and writes
     android/key.properties (gitignored) so local release builds are signed
     with it — or, if both already exist, reuses them untouched,
  2. unless --local-only, sets the four repository secrets
     .github/workflows/release.yml reads: ANDROID_KEYSTORE_BASE64,
     ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_PASSWORD, ANDROID_KEY_ALIAS.

Safe to run again: an existing key is never replaced, so a later run just
(re)uploads the secrets for it.

The password is random and never printed — it lives in key.properties.

BACK UP the keystore and key.properties somewhere safe (a password manager).
Every future release must be signed with this exact key: lose it and no
installed copy of FITNS can ever be updated again — users would have to
uninstall (losing their data) to move to a new key.

Needs `keytool` (any JDK); without --local-only, the GitHub CLI (`gh`),
signed in.
"""

import argparse
import base64
import os
import secrets
import shutil
import string
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROPERTIES = ROOT / "android" / "key.properties"
ALIAS = "fitns"


def find_keytool() -> str:
    """On PATH, under JAVA_HOME, or where a JDK or Android Studio installs it
    — Oracle's Windows installer only puts `java` itself on PATH."""
    found = shutil.which("keytool")
    if found:
        return found
    exe = "keytool.exe" if os.name == "nt" else "keytool"
    candidates = []
    if os.environ.get("JAVA_HOME"):
        candidates.append(Path(os.environ["JAVA_HOME"]) / "bin" / exe)
    for base in (Path(r"C:\Program Files\Java"), Path(r"C:\Program Files\Eclipse Adoptium")):
        if base.is_dir():
            candidates += sorted(base.glob(f"*/bin/{exe}"), reverse=True)
    candidates.append(Path(r"C:\Program Files\Android\Android Studio\jbr\bin") / exe)
    for candidate in candidates:
        if candidate.is_file():
            return str(candidate)
    sys.exit("keytool not found — install a JDK or set JAVA_HOME.")


def create_key(keystore: Path) -> None:
    password = "".join(
        secrets.choice(string.ascii_letters + string.digits) for _ in range(32)
    )
    keystore.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            find_keytool(), "-genkeypair",
            "-keystore", str(keystore), "-storetype", "PKCS12",
            "-alias", ALIAS, "-keyalg", "RSA", "-keysize", "4096",
            "-validity", "10000",
            # PKCS12 has one password for the store and its key.
            "-storepass", password, "-keypass", password,
            "-dname", "CN=FITNS, O=TRAKVRS, C=IN",
        ],
        check=True,
        capture_output=True,
    )
    PROPERTIES.write_text(
        f"storePassword={password}\n"
        f"keyPassword={password}\n"
        f"keyAlias={ALIAS}\n"
        f"storeFile={keystore.as_posix()}\n",
        encoding="utf-8",
    )


def read_properties() -> dict[str, str]:
    pairs = {}
    for line in PROPERTIES.read_text(encoding="utf-8").splitlines():
        key, sep, value = line.partition("=")
        if sep:
            pairs[key.strip()] = value.strip()
    return pairs


def upload_secrets(props: dict[str, str]) -> str:
    repo = subprocess.run(
        ["gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()

    def set_secret(name: str, value: str) -> None:
        subprocess.run(
            ["gh", "secret", "set", name, "--repo", repo],
            input=value.encode(),
            check=True,
            capture_output=True,
        )

    keystore = Path(props["storeFile"])
    set_secret("ANDROID_KEYSTORE_BASE64", base64.b64encode(keystore.read_bytes()).decode())
    set_secret("ANDROID_KEYSTORE_PASSWORD", props["storePassword"])
    set_secret("ANDROID_KEY_PASSWORD", props["keyPassword"])
    set_secret("ANDROID_KEY_ALIAS", props["keyAlias"])
    return repo


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--dir",
        type=Path,
        default=Path.home() / "keys",
        help="where a new keystore goes (default: ~/keys)",
    )
    parser.add_argument(
        "--local-only",
        action="store_true",
        help="create the key and key.properties, but don't set GitHub secrets",
    )
    args = parser.parse_args()

    keystore = args.dir / "fitns-release.jks"
    if PROPERTIES.exists():
        props = read_properties()
        if not Path(props.get("storeFile", "")).exists():
            sys.exit(f"{PROPERTIES} points at a keystore that doesn't exist — fix it by hand.")
        print(f"Using the existing key: {props['storeFile']}")
    elif keystore.exists():
        sys.exit(
            f"{keystore} exists but {PROPERTIES} doesn't — restore key.properties "
            "from your backup rather than making a new key."
        )
    else:
        create_key(keystore)
        props = read_properties()
        print(f"Created keystore: {keystore}")
        print(f"Wrote:            {PROPERTIES}")
        print("Back up both files now — see the note at the top of this script.")

    if args.local_only:
        return
    repo = upload_secrets(props)
    print(f"Secrets set on {repo}: ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, "
          "ANDROID_KEY_PASSWORD, ANDROID_KEY_ALIAS")


if __name__ == "__main__":
    main()
