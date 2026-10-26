import unittest
from unittest.mock import patch
from scripts import collect_costs


class CostTests(unittest.TestCase):
    def test_currency_mismatch_fails_without_reporting_success(self):
        config = {cloud: {"currency": "USD", "budget": 5}
                  for cloud in ("aws", "azure", "gcp")}
        with patch.object(collect_costs, "aws_cost", return_value=(1, "INR")):
            with self.assertRaises(ValueError):
                collect_costs.collect(config)

    def test_currency_and_budget_preserved_per_cloud(self):
        config = {"aws": {"currency": "USD", "budget": 5},
                  "azure": {"currency": "INR", "budget": 500},
                  "gcp": {"currency": "INR", "budget": 500}}
        with patch.object(collect_costs, "aws_cost", return_value=(1, "USD")), patch.object(
                collect_costs, "azure_cost", return_value=(10, "INR")), patch.object(
                collect_costs, "gcp_cost", return_value=(-1, "INR")):
            result = collect_costs.collect(config)
            self.assertEqual(result["clouds"]["azure"]["currency"], "INR")
            self.assertEqual(result["clouds"]["gcp"]["actual"], -1)
            self.assertEqual(result["clouds"]["aws"]["budget"], 5)
