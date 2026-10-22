import unittest
from datetime import datetime, timedelta, timezone
from verify_ios_artifact import verify_metadata


class IosArtifactMetadataTests(unittest.TestCase):
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
