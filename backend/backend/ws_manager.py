from fastapi import WebSocket
from typing import Dict


class WebSocketManager:
    def __init__(self):
        self._connections: Dict[int, WebSocket] = {}

    async def connect(self, user_id: int, websocket: WebSocket):
        await websocket.accept()
        self._connections[user_id] = websocket
        print(f"[WS] user {user_id} connected — active: {list(self._connections.keys())}")

    def disconnect(self, user_id: int):
        self._connections.pop(user_id, None)
        print(f"[WS] user {user_id} disconnected — active: {list(self._connections.keys())}")

    async def send(self, user_id: int, data: dict) -> bool:
        ws = self._connections.get(user_id)
        if ws is None:
            print(f"[WS] send failed — user {user_id} not connected. active: {list(self._connections.keys())}")
            return False
        try:
            await ws.send_json(data)
            print(f"[WS] sent to user {user_id}: type={data.get('type')}")
            return True
        except Exception as e:
            print(f"[WS] send error for user {user_id}: {e}")
            self.disconnect(user_id)
            return False

    def is_connected(self, user_id: int) -> bool:
        return user_id in self._connections


ws_manager = WebSocketManager()
