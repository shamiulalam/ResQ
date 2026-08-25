import firebase_admin

from firebase_admin import (
    auth,
    credentials,
)

from core.config import (
    FIREBASE_SERVICE_ACCOUNT_PATH,
)


class FirebaseAuthService:
    """
    Trusted Firebase Admin operations.

    This service verifies Firebase ID tokens and ensures
    every Firebase-authenticated ResQ user has the custom
    JWT claim required by Supabase:

        role = "authenticated"

    This DOES NOT modify the user's Firestore role/adminLevel.
    """

    def __init__(self) -> None:
        self._initialize_firebase_admin()

    def _initialize_firebase_admin(
        self,
    ) -> None:
        try:
            firebase_admin.get_app()

            # Already initialized.
            return

        except ValueError:
            pass

        if not FIREBASE_SERVICE_ACCOUNT_PATH.exists():
            raise RuntimeError(
                "Firebase service account file "
                "was not found at: "
                f"{FIREBASE_SERVICE_ACCOUNT_PATH}"
            )

        credential = credentials.Certificate(
            str(
                FIREBASE_SERVICE_ACCOUNT_PATH
            )
        )

        firebase_admin.initialize_app(
            credential
        )

    def ensure_supabase_role(
        self,
        id_token: str,
    ) -> tuple[str, bool]:
        """
        Verify Firebase token and ensure the Firebase
        Auth user has:

            role = "authenticated"

        Returns:
            (firebase_uid, claim_changed)
        """

        if not id_token:
            raise ValueError(
                "Firebase ID token is empty."
            )

        # Cryptographically verifies:
        # signature, expiry, audience, issuer, etc.
        decoded_token = auth.verify_id_token(
            id_token
        )

        uid = (
            decoded_token.get("uid")
            or decoded_token.get("sub")
        )

        if not uid:
            raise ValueError(
                "Firebase token does not contain "
                "a valid user ID."
            )

        user_record = auth.get_user(
            uid
        )

        # IMPORTANT:
        #
        # set_custom_user_claims() replaces the complete
        # custom claims object.
        #
        # Therefore we copy existing custom claims first.
        existing_claims = dict(
            user_record.custom_claims
            or {}
        )

        if (
            existing_claims.get("role")
            == "authenticated"
        ):
            return uid, False

        existing_claims["role"] = (
            "authenticated"
        )

        auth.set_custom_user_claims(
            uid,
            existing_claims,
        )

        return uid, True

    def verify_id_token(self, id_token: str) -> str:
        """Verify a Firebase ID token and return its canonical UID."""
        if not id_token:
            raise ValueError("Firebase ID token is empty.")
        decoded_token = auth.verify_id_token(id_token)
        uid = decoded_token.get("uid") or decoded_token.get("sub")
        if not uid:
            raise ValueError("Firebase token does not contain a UID.")
        return str(uid)
