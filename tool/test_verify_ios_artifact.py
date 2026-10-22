import unittest
from io import BytesIO
from zipfile import ZipFile
from datetime import datetime, timedelta, timezone
from verify_ios_artifact import verify_metadata, verify_no_location_api


class IosArtifactMetadataTests(unittest.TestCase):
    def test_rejects_location_in_runner_and_embedded_framework(self):
        for path in ["Payload/Runner.app/Runner", "Payload/Runner.app/Frameworks/SDK.framework/SDK"]:
            for marker in [b"requestWhenInUseAuthorization", b"requestAlwaysAuthorization",
                           b"DKCameraLocationManager", b"_OBJC_CLASS_$_CLLocationManager"]:
                with self.subTest(path=path, marker=marker):
                    stream = BytesIO()
                    with ZipFile(stream, "w") as archive:
                        archive.writestr(path, bytes.fromhex("cffaedfe") + marker)
                    with ZipFile(stream) as archive, self.assertRaises(ValueError):
                        verify_no_location_api(archive)

    def test_checks_native_code_not_resource_text_and_rejects_empty_bundle(self):
        stream = BytesIO()
        with ZipFile(stream, "w") as archive:
            archive.writestr("Payload/Runner.app/Runner", bytes.fromhex("cffaedfe") + b"safe native code")
            archive.writestr("Payload/Runner.app/help.txt", b"requestWhenInUseAuthorization")
        with ZipFile(stream) as archive:
            self.assertEqual(verify_no_location_api(archive), ["Payload/Runner.app/Runner"])
        stream = BytesIO()
        with ZipFile(stream, "w") as archive:
            archive.writestr("Payload/Runner.app/help.txt", b"no executable")
        with ZipFile(stream) as archive, self.assertRaises(ValueError):
            verify_no_location_api(archive)

    def setUp(self):
        self.info = {"CFBundleIdentifier": "space.osia.app", "CFBundleShortVersionString": "0.9.5", "CFBundleVersion": "21"}
        self.profile = {
            "Entitlements": {"application-identifier": "N9NG7B76U8.space.osia.app", "get-task-allow": False},
            "ExpirationDate": datetime.now(timezone.utc) + timedelta(days=30),
        }

    def test_accepts_matching_app_store_identity(self):
        self.assertEqual(verify_metadata(self.info, self.profile, "0.9.5", "21")["build"], "21")

    def test_rejects_changed_identity_version_build_and_development_profile(self):
        for key, value in [("CFBundleIdentifier", "space.osia.app.test"), ("CFBundleShortVersionString", "1.0.0"), ("CFBundleVersion", "20")]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                verify_metadata({**self.info, key: value}, self.profile, "0.9.5", "21")
        for patch in [{"ProvisionedDevices": ["test-only-device"]}, {"ProvisionsAllDevices": True}, {"ExpirationDate": datetime(2020, 1, 1)}]:
            with self.subTest(patch=patch), self.assertRaises(ValueError):
                verify_metadata(self.info, {**self.profile, **patch}, "0.9.5", "21")
        with self.assertRaises(ValueError):
            verify_metadata(self.info, {**self.profile, "Entitlements": {"application-identifier": "N9NG7B76U8.space.osia.app", "get-task-allow": True}}, "0.9.5", "21")


if __name__ == "__main__":
    unittest.main()
