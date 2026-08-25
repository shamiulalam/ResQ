import unittest
from types import SimpleNamespace
from unittest.mock import patch

from services.firebase_auth_service import FirebaseAuthService


class FirebaseAuthServiceTests(unittest.TestCase):
    def setUp(self):
        initializer = patch.object(
            FirebaseAuthService, "_initialize_firebase_admin"
        )
        self.addCleanup(initializer.stop)
        initializer.start()
        self.service = FirebaseAuthService()

    @patch("services.firebase_auth_service.auth.set_custom_user_claims")
    @patch("services.firebase_auth_service.auth.get_user")
    @patch("services.firebase_auth_service.auth.verify_id_token")
    def test_adds_supabase_role_without_losing_existing_claims(
        self, verify_id_token, get_user, set_claims
    ):
        verify_id_token.return_value = {"uid": "firebase-user"}
        get_user.return_value = SimpleNamespace(
            custom_claims={"adminLevel": "super"}
        )

        result = self.service.ensure_supabase_role("token")

        self.assertEqual(("firebase-user", True), result)
        set_claims.assert_called_once_with(
            "firebase-user",
            {"adminLevel": "super", "role": "authenticated"},
        )

    @patch("services.firebase_auth_service.auth.set_custom_user_claims")
    @patch("services.firebase_auth_service.auth.get_user")
    @patch("services.firebase_auth_service.auth.verify_id_token")
    def test_does_not_rewrite_an_existing_supabase_role(
        self, verify_id_token, get_user, set_claims
    ):
        verify_id_token.return_value = {"sub": "firebase-user"}
        get_user.return_value = SimpleNamespace(
            custom_claims={"role": "authenticated", "adminLevel": "super"}
        )

        result = self.service.ensure_supabase_role("token")

        self.assertEqual(("firebase-user", False), result)
        set_claims.assert_not_called()


if __name__ == "__main__":
    unittest.main()
