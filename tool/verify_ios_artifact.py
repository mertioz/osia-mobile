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


def verify_native_payload(bundle: ZipFile) -> list[str]:
    """Check every shipped Mach-O for native code rejected by App Review.

    Build22 passed source-only checks but Apple's ITMS-90683 scanner found
    DKCamera's location API in Runner. Build30 contained flutter_webrtc's
    private ReplayKit selector and was rejected under guideline 2.5.1.
    """
    magic = {bytes.fromhex(value) for value in
             ("cffaedfe", "cefaedfe", "cafebabe", "bebafeca", "cafebabf", "bfbafeca")}
    forbidden = (b"requestWhenInUseAuthorization", b"requestAlwaysAuthorization",
                 b"DKCameraLocationManager", b"_OBJC_CLASS_$_CLLocationManager")
    native_files = []
    for name in bundle.namelist():
        if not name.startswith("Payload/") or name.endswith("/"):
            continue
        if "/integration_test.framework/" in name:
            raise ValueError(f"Integration-test framework remains in {name}")
        with bundle.open(name) as entry:
            header = entry.read(4)
            if header not in magic:
                continue
            data = header + entry.read()
        native_files.append(name)
        if any(marker in data for marker in forbidden):
            raise ValueError(f"Unused native location API remains in {name}")
        if b"buttonPressed:" in data:
            raise ValueError(f"Private ReplayKit selector buttonPressed: remains in {name}")
        if (b"plugins.flutter.io/integration_test" in data
                or b"_OBJC_CLASS_$_IntegrationTestPlugin" in data):
            raise ValueError(f"Native integration-test plugin remains in {name}")
    if not native_files:
        raise ValueError("IPA contains no native executable to inspect")
    return native_files


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


def source_product_version(pubspec: str, version_source: str) -> str:
    """Require one valid native version shared by pubspec and product metadata."""
    numeric = r"(?:0|[1-9][0-9]*)"
    versions = re.findall(
        rf"^version:[ \t]*({numeric}\.{numeric}\.{numeric})\+[1-9][0-9]*[ \t]*$",
        pubspec, re.M,
    )
    declared = re.findall(r"^const productVersion = '([^']+)';$", version_source, re.M)
    if len(versions) != 1 or declared != versions:
        raise ValueError("Mobile source versions are missing, invalid or inconsistent")
    return versions[0]


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    version = source_product_version(
        (root / "pubspec.yaml").read_text(encoding="utf-8"),
        (root / "lib/product_version.dart").read_text(encoding="utf-8"),
    )
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
        native_files = verify_native_payload(bundle)
    metadata = verify_metadata(info, profile, version, build)
    archive_info = plistlib.loads((archive_app / "Info.plist").read_bytes())
    verify_metadata(archive_info, profile, version, build)
    metadata.update(
        source_commit=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
        sha256=hashlib.sha256(ipa.read_bytes()).hexdigest(),
        size_bytes=ipa.stat().st_size,
        archive_signature_verified=True,
        location_api_absent=True,
        private_replaykit_selector_absent=True,
        integration_test_plugin_absent=True,
        inspected_native_files=native_files,
        device_verified=False,
    )
    (ipa.parent / "OSIA-build-metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()
