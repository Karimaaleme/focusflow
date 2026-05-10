from firebase_admin import messaging


def send_push(token: str, title: str, body: str, data: dict = None) -> bool:
    """Send an FCM push notification to a single device token. Returns True on success."""
    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            token=token,
            data={k: str(v) for k, v in (data or {}).items()},
            android=messaging.AndroidConfig(
                notification=messaging.AndroidNotification(
                    channel_id="focusflow_channel",
                    priority="high",
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default"),
                ),
            ),
        )
        messaging.send(message)
        return True
    except Exception as e:
        print(f"[FCM] Send failed: {e}")
        return False


def send_push_to_user(user, title: str, body: str, data: dict = None) -> bool:
    """Send push to a user if they have a token and push enabled."""
    if not user.fcm_token:
        return False
    profile = getattr(user, 'profile', None)
    if profile and not profile.notifications_push:
        return False
    return send_push(user.fcm_token, title, body, data)
