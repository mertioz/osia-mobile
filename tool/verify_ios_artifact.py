"""Verify the actual signed iOS archive and exported IPA on the macOS CI host."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
from datetime import datetime, timezone
from zipfile import ZipFile


def verify_metadata(info: dict, profile: dict, version: str, build: str) -> dict:
    if (info.get("CFBundleIdentifier") != "space.osia.app"
            or info.get("CFBundleShortVersionString") != version
            or str(info.get("CFBundleVersion")) != build):
        raise ValueError("Exported iOS identity does not match the selected source build")
    entitlements = profile.get("Entitlements", {})
    if (entitlements.get("application-identifier") != "N9NG7B76U8.space.osia.app"
            or entitlements.get("get-task-allow") is not False
            or profile.get("ProvisionedDevices") is not None
            or profile.get("ProvisionsAllDevices") is True):
        raise ValueError("Expected the existing OSIA App Store distribution identity")
    expiry = profile.get("ExpirationDate")
    if not isinstance(expiry, datetime) or expiry.replace(tzinfo=timezone.utc) <= datetime.now(timezone.utc):
        raise ValueError("iOS distribution profile is expired or has no valid expiry")
    return {
        "bundle_id": info["CFBundleIdentifier"],
        "version": version,
        "build": build,
        "application_identifier": entitlements["application-identifier"],
        "profile_expires_at": expiry.replace(tzinfo=timezone.utc).isoformat(),
    }


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    version_match = re.search(r"^version:\s*([^+\s]+)\+\d+\s*$", (root / "pubspec.yaml").read_text(), re.M)
    if not version_match or version_match[1] != "0.9.5":
        raise ValueError("Mobile product version must remain 0.9.5")
    build = os.environ["IOS_BUILD_NUMBER"]
    archive_app = root / "build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app"
    subprocess.run(["codesign", "--verify", "--deep", "--strict", "--verbose=2", str(archive_app)],
                   check=True, capture_output=True)
    profile_bytes = subprocess.check_output(
        ["security", "cms", "-D", "-i", str(archive_app / "embedded.mobileprovision")],
        stderr=subprocess.PIPE,
    )
    profile = plistlib.loads(profile_bytes)
    archives = list((root / "build/ios/ipa").glob("*.ipa"))
    if len(archives) != 1:
        raise ValueError("Expected exactly one exported IPA")
    ipa = archives[0]
    with ZipFile(ipa) as bundle:
        info_paths = [name for name in bundle.namelist()
                      if name.startswith("Payload/") and name.endswith(".app/Info.plist") and name.count("/") == 2]
        if len(info_paths) != 1:
            raise ValueError("Expected exactly one application in the IPA")
        info = plistlib.loads(bundle.read(info_paths[0]))
    metadata = verify_metadata(info, profile, version_match[1], build)
    archive_info = plistlib.loads((archive_app / "Info.plist").read_bytes())
    verify_metadata(archive_info, profile, version_match[1], build)
    metadata.update(
        source_commit=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
        sha256=hashlib.sha256(ipa.read_bytes()).hexdigest(),
        size_bytes=ipa.stat().st_size,
        archive_signature_verified=True,
        device_verified=False,
    )
    (ipa.parent / "OSIA-build-metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()
