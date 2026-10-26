import json
import unittest
from scripts.ci_config import configuration


class ConfigTests(unittest.TestCase):
    def test_missing_config_is_rejected(self):
        with self.assertRaises(ValueError):
            configuration({})

    def test_release_override_preserves_environment_flags(self):
        config = dict(gcp_project_id="project", gcp_bucket_name="gcp",
                      bucket_name="aws", azure_acr_name="acr",
                      enable_global_routing=False)
        result = configuration({"TF_CONFIG_JSON": json.dumps(config),
                                "AZURE_IMAGE": "registry/image@sha256:abc"})
        self.assertFalse(result["enable_global_routing"])
        self.assertEqual(result["azure_image"], "registry/image@sha256:abc")

    def test_credentials_are_rejected(self):
        config = dict(gcp_project_id="project", gcp_bucket_name="gcp",
                      bucket_name="aws", azure_acr_name="acr", client_secret="test")
        with self.assertRaises(ValueError):
            configuration({"TF_CONFIG_JSON": json.dumps(config)})
