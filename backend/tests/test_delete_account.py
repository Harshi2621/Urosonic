"""
test_delete_account.py — Unit Tests for DELETE /profile/<user_id> (Account Deletion)
=================================================================================
Validates:
1. Deleting an existing user permanently (App Store Guideline 5.1.1(v) compliance)
2. Soft delete / deactivate with mode=deactivate
3. 404 response when user does not exist
4. Password validation when confirmation password is supplied
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


class DeleteAccountTestCase(unittest.TestCase):
    def setUp(self):
        self.app = create_app()
        self.client = self.app.test_client()

    @patch("routes.profile.query")
    @patch("routes.profile.execute")
    def test_delete_account_permanent_success(self, mock_execute, mock_query):
        mock_query.return_value = {
            "id": 42,
            "role": "patient",
            "password_hash": "plain_or_hash",
        }
        resp = self.client.delete("/profile/42")
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()
        self.assertIn("deleted permanently", data["message"].lower())
        mock_execute.assert_called_once_with("DELETE FROM users WHERE id = %s", (42,))

    @patch("routes.profile.query")
    @patch("routes.profile.execute")
    def test_delete_account_deactivate_mode(self, mock_execute, mock_query):
        mock_query.return_value = {
            "id": 42,
            "role": "patient",
            "password_hash": "plain_or_hash",
        }
        resp = self.client.delete("/profile/42?mode=deactivate")
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()
        self.assertIn("deactivated", data["message"].lower())
        mock_execute.assert_called_once_with("UPDATE users SET is_active = 0 WHERE id = %s", (42,))

    @patch("routes.profile.query")
    def test_delete_account_not_found(self, mock_query):
        mock_query.return_value = None
        resp = self.client.delete("/profile/999")
        self.assertEqual(resp.status_code, 404)
        data = resp.get_json()
        self.assertEqual(data["error"], "User not found")

    @patch("routes.profile.query")
    @patch("routes.profile.execute")
    def test_delete_account_incorrect_password(self, mock_execute, mock_query):
        mock_query.return_value = {
            "id": 42,
            "role": "patient",
            "password_hash": "correct_password",
        }
        resp = self.client.delete(
            "/profile/42",
            data=json.dumps({"password": "wrong_password"}),
            content_type="application/json"
        )
        self.assertEqual(resp.status_code, 401)
        data = resp.get_json()
        self.assertEqual(data["error"], "Incorrect password")
        mock_execute.assert_not_called()


if __name__ == "__main__":
    unittest.main()
