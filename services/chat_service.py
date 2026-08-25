from functools import lru_cache
from pathlib import PurePosixPath

from firebase_admin import firestore, messaging
from supabase import Client, create_client

from core.config import (
    CHAT_MEDIA_BUCKET,
    SUPABASE_SERVICE_ROLE_KEY,
    SUPABASE_URL,
)


class ChatBackendService:
    def __init__(self) -> None:
        self.firestore = firestore.client()
        self.supabase: Client | None = None
        if SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY:
            self.supabase = create_client(
                SUPABASE_URL,
                SUPABASE_SERVICE_ROLE_KEY,
            )

    def require_participant(self, uid: str, conversation_id: str) -> dict:
        snapshot = self.firestore.collection("conversations").document(
            conversation_id
        ).get()
        if not snapshot.exists:
            raise LookupError("Conversation does not exist.")
        data = snapshot.to_dict() or {}
        if uid not in data.get("participantIds", []):
            raise PermissionError("User is not a conversation participant.")
        return data

    def list_chat_users(self, uid: str, limit: int = 100) -> list[dict]:
        users = []
        for snapshot in self.firestore.collection("users").limit(limit).stream():
            if snapshot.id == uid:
                continue
            data = snapshot.to_dict() or {}
            users.append({
                "uid": snapshot.id,
                "firstName": data.get("firstName", ""),
                "lastName": data.get("lastName", ""),
                "profileImage": data.get("profileImage", data.get("photoUrl", "")),
                "subtitle": data.get("subtitle", data.get("roleLabel", "")),
                "isVerified": bool(data.get("isVerified", False)),
            })
        return users

    def upload_media(
        self,
        *,
        uid: str,
        conversation_id: str,
        message_id: str,
        filename: str,
        content_type: str,
        content: bytes,
    ) -> str:
        self.require_participant(uid, conversation_id)
        if self.supabase is None:
            raise RuntimeError("Supabase chat media is not configured.")
        safe_name = PurePosixPath(filename).name.replace(" ", "_")
        object_path = f"{conversation_id}/{uid}/{message_id}/{safe_name}"
        self.supabase.storage.from_(CHAT_MEDIA_BUCKET).upload(
            object_path,
            content,
            {"content-type": content_type, "upsert": "false"},
        )
        return object_path

    def signed_url(
        self,
        *,
        uid: str,
        conversation_id: str,
        object_path: str,
    ) -> str:
        self.require_participant(uid, conversation_id)
        if self.supabase is None:
            raise RuntimeError("Supabase chat media is not configured.")
        prefix = f"{conversation_id}/"
        if not object_path.startswith(prefix) or ".." in object_path:
            raise PermissionError("Invalid media object path.")
        response = self.supabase.storage.from_(CHAT_MEDIA_BUCKET).create_signed_url(
            object_path,
            300,
        )
        url = response.get("signedURL") or response.get("signedUrl")
        if not url:
            raise RuntimeError("Supabase did not return a signed URL.")
        return str(url)

    def notify_message(
        self,
        *,
        uid: str,
        conversation_id: str,
        message_id: str,
    ) -> int:
        conversation = self.require_participant(uid, conversation_id)
        message_snapshot = (
            self.firestore.collection("conversations")
            .document(conversation_id)
            .collection("messages")
            .document(message_id)
            .get()
        )
        if not message_snapshot.exists:
            raise LookupError("Message does not exist.")
        message_data = message_snapshot.to_dict() or {}
        if message_data.get("senderId") != uid:
            raise PermissionError("Only the sender may dispatch notification.")
        recipient = next(
            participant
            for participant in conversation.get("participantIds", [])
            if participant != uid
        )
        preference = (
            self.firestore.collection("users")
            .document(recipient)
            .collection("chatPreferences")
            .document(conversation_id)
            .get()
        )
        if preference.exists and (preference.to_dict() or {}).get("muted"):
            return 0
        device_documents = (
            self.firestore.collection("users")
            .document(recipient)
            .collection("devices")
            .stream()
        )
        tokens = [
            data["token"]
            for document in device_documents
            if (data := document.to_dict() or {}).get("token")
        ]
        if not tokens:
            return 0
        sender_profile = self.firestore.collection("users").document(uid).get()
        sender_data = sender_profile.to_dict() or {}
        sender_name = " ".join(
            value
            for value in [
                sender_data.get("firstName", ""),
                sender_data.get("lastName", ""),
            ]
            if value
        ) or "ResQ user"
        message_type = message_data.get("type", "text")
        body = message_data.get("text", "").strip()
        if not body:
            body = {
                "image": "Sent a photo",
                "video": "Sent a video",
                "file": "Sent a file",
            }.get(message_type, "Sent a message")
        result = messaging.send_each_for_multicast(
            messaging.MulticastMessage(
                tokens=tokens,
                notification=messaging.Notification(
                    title=sender_name,
                    body=body[:120],
                ),
                data={
                    "type": "chat",
                    "conversationId": conversation_id,
                    "senderUid": uid,
                    "messageId": message_id,
                    "senderName": sender_name,
                },
                android=messaging.AndroidConfig(
                    notification=messaging.AndroidNotification(
                        channel_id="resq_messages",
                    )
                ),
            )
        )
        return result.success_count


@lru_cache(maxsize=1)
def get_chat_backend_service() -> ChatBackendService:
    return ChatBackendService()
