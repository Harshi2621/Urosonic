"""
test_fluid.py — Unit Tests for Fluid Intake, Urine Output & Fluid Balance Endpoints
==================================================================================
Tests:
1. GET /fluid/patient/<id> (Intake logs)
2. POST /fluid (Add drink intake log)
3. POST /fluid missing required fields (HTTP 400)
4. DELETE /fluid/<entry_id>
5. GET /fluid/patient/<id>/output (Urine output logs)
6. POST /fluid/output (Add urine output log)
7. POST /fluid/output missing fields (HTTP 400)
8. DELETE /fluid/output/<entry_id>
9. GET /fluid/patient/<id>/balance (Intake vs. Output Net Balance)
"""

import json
import os
import sys
import unittest
from unittest.mock import patch, MagicMock

BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from app import create_app


class TestFluidRoutes(unittest.TestCase):

    def setUp(self):
        self.app = create_app()
        self.app.config["TESTING"] = True
        self.client = self.app.test_client()

    @patch("routes.fluid.query")
    def test_01_get_fluid_logs(self, mock_query):
        mock_query.return_value = [
            {"id": 1, "patient_id": 10, "drink_type": "Water", "volume_ml": 250, "logged_at": "10:00 AM", "log_date": None}
        ]
        res = self.client.get("/fluid/patient/10")
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertEqual(data["total_ml"], 250)
        self.assertEqual(len(data["entries"]), 1)

    @patch("routes.fluid.execute")
    @patch("routes.fluid.query")
    def test_02_add_fluid_log(self, mock_query, mock_execute):
        mock_execute.return_value = 1
        mock_query.return_value = {
            "id": 1, "patient_id": 10, "drink_type": "Water", "volume_ml": 300, "logged_at": "11:00 AM", "log_date": None
        }
        res = self.client.post("/fluid", json={
            "patient_id": 10,
            "drink_type": "Water",
            "volume_ml": 300,
            "logged_at": "11:00 AM"
        })
        self.assertEqual(res.status_code, 201)
        data = res.get_json()
        self.assertEqual(data["entry"]["volume_ml"], 300)

    def test_03_add_fluid_missing_fields(self):
        res = self.client.post("/fluid", json={"patient_id": 10})
        self.assertEqual(res.status_code, 400)

    @patch("routes.fluid._ensure_output_table")
    @patch("routes.fluid.query")
    def test_04_get_urine_output_logs(self, mock_query, mock_ensure):
        mock_query.return_value = [
            {
                "id": 1,
                "patient_id": 10,
                "volume_ml": 350,
                "urgency": "Normal",
                "color": "Pale Yellow",
                "source": "Manual",
                "logged_at": "1:15 PM",
                "log_date": None,
                "notes": "Healthy void"
            }
        ]
        res = self.client.get("/fluid/patient/10/output")
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertEqual(data["total_ml"], 350)
        self.assertEqual(data["count"], 1)
        self.assertEqual(data["entries"][0]["urgency"], "Normal")

    @patch("routes.fluid._ensure_output_table")
    @patch("routes.fluid.execute")
    @patch("routes.fluid.query")
    def test_05_add_urine_output_log(self, mock_query, mock_execute, mock_ensure):
        mock_execute.return_value = 2
        mock_query.return_value = {
            "id": 2,
            "patient_id": 10,
            "volume_ml": 250,
            "urgency": "Mild Urgency",
            "color": "Transparent Yellow",
            "source": "Manual",
            "logged_at": "2:30 PM",
            "log_date": None,
            "notes": ""
        }
        res = self.client.post("/fluid/output", json={
            "patient_id": 10,
            "volume_ml": 250,
            "urgency": "Mild Urgency",
            "color": "Transparent Yellow",
            "logged_at": "2:30 PM"
        })
        self.assertEqual(res.status_code, 201)
        data = res.get_json()
        self.assertEqual(data["entry"]["volume_ml"], 250)
        self.assertEqual(data["entry"]["urgency"], "Mild Urgency")

    def test_06_add_urine_output_missing_fields(self):
        res = self.client.post("/fluid/output", json={"patient_id": 10})
        self.assertEqual(res.status_code, 400)

    @patch("routes.fluid._ensure_output_table")
    @patch("routes.fluid.execute")
    @patch("routes.fluid.query")
    def test_07_delete_urine_output_log(self, mock_query, mock_execute, mock_ensure):
        mock_query.return_value = {"id": 2}
        res = self.client.delete("/fluid/output/2")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.get_json()["message"], "Deleted")

    @patch("routes.fluid._ensure_output_table")
    @patch("routes.fluid.query")
    def test_08_fluid_balance(self, mock_query, mock_ensure):
        # 1st call for intake_rows, 2nd call for output_rows
        intake_rows = [
            {"id": 1, "patient_id": 10, "drink_type": "Water", "volume_ml": 500, "logged_at": "9:00 AM", "log_date": None}
        ]
        output_rows = [
            {"id": 1, "patient_id": 10, "volume_ml": 300, "urgency": "Normal", "color": "Pale Yellow", "source": "Manual", "logged_at": "11:00 AM", "log_date": None, "notes": ""}
        ]
        mock_query.side_effect = [intake_rows, output_rows]

        res = self.client.get("/fluid/patient/10/balance?date=2026-09-29")
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertEqual(data["intake_total_ml"], 500)
        self.assertEqual(data["output_total_ml"], 300)
        self.assertEqual(data["net_balance_ml"], 200)
        self.assertEqual(data["void_count"], 1)


if __name__ == "__main__":
    unittest.main()
