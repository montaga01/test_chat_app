# ========== الرافع - باك اند المحادثات ==========
# النسخة المعدّلة والمحسّنة

import asyncio
import json
import os
import sqlite3
from datetime import datetime, timedelta
from typing import Dict

import firebase_admin
from fastapi import BackgroundTasks, Depends, FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.staticfiles import StaticFiles
from firebase_admin import credentials, messaging
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel


# ========== Firebase ==========
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)


def send_fcm_notification(fcm_token: str, title: str, body: str):
    """إرسال إشعار FCM للمستخدم"""
    if not fcm_token:
        return
    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            token=fcm_token
        )
        messaging.send(message)
    except Exception as e:
        print(f"خطأ في إرسال FCM: {e}")


# ========== إعداد التطبيق ==========
app = FastAPI(title="الرافع API - المحادثات", version="2.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ⚠️ في الإنتاج: ضع هذه القيمة في متغير بيئة SECRET_KEY
SECRET_KEY = os.environ.get("SECRET_KEY", "alrafeeg-super-secret-key-change-in-production-2024")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_DAYS = 30

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()


# ========== نماذج البيانات ==========
class RegisterModel(BaseModel):
    name: str
    email: str
    password: str


class LoginModel(BaseModel):
    email: str
    password: str


class SearchModel(BaseModel):
    query: str


class SendMessageModel(BaseModel):
    receiver_id: int
    content: str


class TokenUpdate(BaseModel):
    fcm_token: str


# ========== إدارة اتصالات WebSocket ==========
class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[int, WebSocket] = {}

    async def connect(self, websocket: WebSocket, user_id: int):
        await websocket.accept()
        self.active_connections[user_id] = websocket

    def disconnect(self, user_id: int):
        if user_id in self.active_connections:
            del self.active_connections[user_id]

    async def send_personal_message(self, message: str, user_id: int):
        if user_id in self.active_connections:
            try:
                await self.active_connections[user_id].send_text(message)
            except Exception as e:
                print(f"خطأ في إرسال WebSocket للمستخدم {user_id}: {e}")
                self.disconnect(user_id)


manager = ConnectionManager()


# ========== قاعدة البيانات ==========
DB_PATH = "alrafeeg.db"


def init_db():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # جدول المستخدمين
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            fcm_token TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    # جدول الرسائل
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sender_id INTEGER NOT NULL,
            receiver_id INTEGER NOT NULL,
            content TEXT NOT NULL,
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(sender_id) REFERENCES users(id),
            FOREIGN KEY(receiver_id) REFERENCES users(id)
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS last_read (
            user_id    INTEGER NOT NULL,
            peer_id    INTEGER NOT NULL,
            message_id INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (user_id, peer_id)
        )
    """)

    conn.commit()
    conn.close()


init_db()


# ========== دوال مساعدة ==========
def get_user_fcm_token(user_id: int) -> str | None:
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT fcm_token FROM users WHERE id = ?", (user_id,))
    row = cursor.fetchone()
    conn.close()
    return row[0] if row else None


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=ACCESS_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """
    ✅ التوكن يُقرأ من Authorization Header (Bearer token)
    بدلاً من query param لحماية أمان التطبيق
    """
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=401, detail="توكن غير صالح")

        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute("SELECT id, name, email FROM users WHERE id = ?", (int(user_id),))
        user = cursor.fetchone()
        conn.close()

        if user is None:
            raise HTTPException(status_code=401, detail="المستخدم غير موجود")
        return dict(user)
    except JWTError:
        raise HTTPException(status_code=401, detail="توكن غير صالح")


# ========== مسارات API ==========

@app.get("/")
def home():
    return {"status": "success", "message": "باك اند الرافع للمحادثات شغال ✅"}


@app.post("/api/register")
def register(data: RegisterModel):
    if len(data.password) < 6:
        raise HTTPException(status_code=400, detail="كلمة المرور يجب أن تكون 6 أحرف على الأقل")

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT id FROM users WHERE email = ?", (data.email,))
    if cursor.fetchone():
        conn.close()
        raise HTTPException(status_code=409, detail="البريد الإلكتروني مستخدم بالفعل")

    hashed_password = get_password_hash(data.password)
    cursor.execute(
        "INSERT INTO users (name, email, password) VALUES (?, ?, ?)",
        (data.name, data.email, hashed_password)
    )
    conn.commit()
    user_id = cursor.lastrowid
    conn.close()

    return {"status": "success", "message": "تم التسجيل بنجاح", "data": {"id": user_id, "name": data.name}}


@app.post("/api/login")
def login(data: LoginModel):
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE email = ?", (data.email,))
    user = cursor.fetchone()
    conn.close()

    if not user or not verify_password(data.password, user["password"]):
        raise HTTPException(status_code=401, detail="بريد إلكتروني أو كلمة مرور خاطئة")

    token = create_access_token(data={"sub": str(user["id"])})
    return {
        "status": "success",
        "message": "تم تسجيل الدخول بنجاح",
        "data": {
            "token": token,
            "user": {"id": user["id"], "name": user["name"], "email": user["email"]}
        }
    }


@app.post("/api/users/search")
def search_users(data: SearchModel, current_user: dict = Depends(get_current_user)):
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    query = "SELECT id, name, email FROM users WHERE (name LIKE ? OR CAST(id AS TEXT) = ?) AND id != ?"
    search_term = f"%{data.query}%"
    cursor.execute(query, (search_term, data.query, current_user["id"]))
    users = [dict(row) for row in cursor.fetchall()]
    conn.close()

    return {"status": "success", "data": users}


@app.get("/api/chats")
def get_chats(current_user: dict = Depends(get_current_user)):
    """
    ✅ استعلام محسّن: يرجع آخر رسالة فعلية مع كل مستخدم
    """
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    query = """
        SELECT m.id, m.sender_id, m.receiver_id, m.content, m.timestamp,
               u.name, u.id as user_id,
               (
                   SELECT COUNT(*) FROM messages m3
                   WHERE m3.sender_id = u.id
                     AND m3.receiver_id = :uid
                     AND m3.id > COALESCE(
                         (SELECT last_read_id FROM user_reads 
                          WHERE user_id = :uid AND peer_id = u.id), 0
                     )
               ) as unread_count
        FROM messages m
        JOIN users u ON (
            CASE WHEN m.sender_id = :uid THEN m.receiver_id = u.id
                 ELSE m.sender_id = u.id END
        )
        WHERE (m.sender_id = :uid OR m.receiver_id = :uid)
          AND m.timestamp = (
              SELECT MAX(m2.timestamp) FROM messages m2
              WHERE (m2.sender_id = m.sender_id AND m2.receiver_id = m.receiver_id)
                 OR (m2.sender_id = m.receiver_id AND m2.receiver_id = m.sender_id)
          )
        GROUP BY u.id
        ORDER BY m.timestamp DESC
    """
    cursor.execute(query, {"uid": current_user["id"]})
    chats = [dict(row) for row in cursor.fetchall()]
    conn.close()

    return {"status": "success", "data": chats}


@app.get("/api/messages/{with_user_id}")
def get_messages(with_user_id: int, current_user: dict = Depends(get_current_user)):
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    query = """
        SELECT * FROM messages
        WHERE (sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)
        ORDER BY timestamp ASC
    """
    cursor.execute(query, (current_user["id"], with_user_id, with_user_id, current_user["id"]))
    messages = [dict(row) for row in cursor.fetchall()]
    conn.close()

    return {"status": "success", "data": messages}


@app.post("/api/messages/send")
def send_message_via_http(
    data: SendMessageModel,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user)
):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO messages (sender_id, receiver_id, content) VALUES (?, ?, ?)",
        (current_user["id"], data.receiver_id, data.content)
    )
    conn.commit()
    msg_id = cursor.lastrowid
    conn.close()

    now = datetime.utcnow().isoformat()
    msg_payload = json.dumps({
        "id": msg_id,
        "sender_id": current_user["id"],
        "receiver_id": data.receiver_id,
        "content": data.content,
        "timestamp": now
    })

    # إرسال عبر WebSocket إذا كان المستقبل متصلاً
    background_tasks.add_task(manager.send_personal_message, msg_payload, data.receiver_id)

    # إرسال إشعار FCM
    fcm_token = get_user_fcm_token(data.receiver_id)
    if fcm_token:
        background_tasks.add_task(
            send_fcm_notification,
            fcm_token,
            f"رسالة جديدة من {current_user['name']}",
            data.content
        )

    return {
        "status": "success",
        "data": {
            "id": msg_id,
            "sender_id": current_user["id"],
            "receiver_id": data.receiver_id,
            "content": data.content,
            "timestamp": now
        }
    }


@app.post("/api/update-fcm-token")
def update_fcm_token(data: TokenUpdate, current_user: dict = Depends(get_current_user)):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("UPDATE users SET fcm_token = ? WHERE id = ?", (data.fcm_token, current_user["id"]))
    conn.commit()
    conn.close()
    return {"status": "success"}


# ========== WebSocket للمحادثة المباشرة ==========
@app.websocket("/ws/chat/{token}")
async def websocket_endpoint(websocket: WebSocket, token: str):
    """
    WebSocket يقبل التوكن في الـ path لأن WebSocket
    لا يدعم Authorization Header بشكل مباشر
    """
    user = None
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")

        if not user_id:
            await websocket.close(code=4001, reason="توكن فاضي")
            return

        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute("SELECT id, name, email FROM users WHERE id = ?", (int(user_id),))
        user_row = cursor.fetchone()
        conn.close()

        if not user_row:
            await websocket.close(code=4001, reason="مستخدم غير موجود")
            return

        user = dict(user_row)

    except Exception as e:
        print(f"خطأ في توكن WebSocket: {e}")
        await websocket.close(code=4002, reason="خطأ في التوكن")
        return

    await manager.connect(websocket, user["id"])
    print(f"المستخدم {user['name']} متصل عبر WebSocket")

    try:
        while True:
            data = await websocket.receive_text()
            
            # ── ping/pong ──
            if data == "ping":
                await websocket.send_text("pong")
                continue
            
            try:
                msg_data = json.loads(data)
            except json.JSONDecodeError:
                continue
            
            msg_type = msg_data.get("type")
            
            # ── presence ──
            if msg_type == "presence":
                online = msg_data.get("online", True)
                if not online:
                    # أعلن للكل إن المستخدم offline
                    offline_payload = json.dumps({
                        "type": "presence",
                        "user_id": user["id"],
                        "online": False,
                        "last_seen": datetime.utcnow().isoformat()
                    })
                    for uid, ws in list(manager.active_connections.items()):
                        if uid != user["id"]:
                            try:
                                await ws.send_text(offline_payload)
                            except Exception:
                                manager.disconnect(uid)
                else:
                    # أعلن online
                    online_payload = json.dumps({
                        "type": "presence",
                        "user_id": user["id"],
                        "online": True,
                        "last_seen": datetime.utcnow().isoformat()
                    })
                    for uid, ws in list(manager.active_connections.items()):
                        if uid != user["id"]:
                            try:
                                await ws.send_text(online_payload)
                            except Exception:
                                manager.disconnect(uid)
                continue
            
            # ── get_presence (طلب حالة مستخدم) ──
            if msg_type == "get_presence":
                user_ids = msg_data.get("user_ids", [])
                for uid in user_ids:
                    is_online = uid in manager.active_connections
                    presence_payload = json.dumps({
                        "type": "presence",
                        "user_id": uid,
                        "online": is_online,
                        "last_seen": datetime.utcnow().isoformat()
                    })
                    try:
                        await websocket.send_text(presence_payload)
                    except Exception:
                        break
                continue
            
            # ── typing ──
            if msg_type == "typing":
                receiver_id = msg_data.get("receiver_id")
                if receiver_id and receiver_id in manager.active_connections:
                    typing_payload = json.dumps({
                        "type": "typing",
                        "sender_id": user["id"]
                    })
                    try:
                        await manager.active_connections[receiver_id].send_text(typing_payload)
                    except Exception:
                        manager.disconnect(receiver_id)
                continue
            
            # ── رسالة عادية ──
            receiver_id = msg_data.get("receiver_id")
            content = msg_data.get("content")
        
            if not receiver_id or not content:
                await websocket.send_text(json.dumps({"error": "بيانات ناقصة"}))
                continue
        
            # ... باقي كود الرسالة كما هو

            # حفظ الرسالة في قاعدة البيانات
            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO messages (sender_id, receiver_id, content) VALUES (?, ?, ?)",
                (user["id"], receiver_id, content)
            )
            conn.commit()
            message_id = cursor.lastrowid
            conn.close()

            message_payload = json.dumps({
                "id": message_id,
                "sender_id": user["id"],
                "receiver_id": receiver_id,
                "content": content,
                "timestamp": datetime.utcnow().isoformat()
            })

            # إرسال للمستقبل عبر WebSocket
            await manager.send_personal_message(message_payload, receiver_id)

            # إرسال إشعار FCM في thread منفصل
            fcm_token = get_user_fcm_token(receiver_id)
            if fcm_token:
                asyncio.create_task(
                    asyncio.to_thread(
                        send_fcm_notification,
                        fcm_token,
                        f"رسالة من {user['name']}",
                        content
                    )
                )

            # تأكيد الإرسال للمرسل
            await websocket.send_text(json.dumps({"status": "sent", "message_id": message_id}))

    except WebSocketDisconnect:
        manager.disconnect(user["id"])
        print(f"المستخدم {user['name']} قطع الاتصال")
        
        # أعلن offline لكل المتصلين
        offline_payload = json.dumps({
            "type": "presence",
            "user_id": user["id"],
            "online": False,
            "last_seen": datetime.utcnow().isoformat()
        })
        for uid, ws in list(manager.active_connections.items()):
            try:
                await ws.send_text(offline_payload)
            except Exception:
                manager.disconnect(uid)

# ========== ملفات ثابتة ==========
@app.get("/firebase-messaging-sw.js")
async def get_service_worker():
    file_path = os.path.join(os.getcwd(), "firebase-messaging-sw.js")
    if os.path.exists(file_path):
        return FileResponse(file_path, media_type="application/javascript")
    return {"error": "File not found on server"}


app.mount("/web", StaticFiles(directory="web", html=True), name="web")
app.mount("/test", StaticFiles(directory="test", html=True), name="test")

@app.post("/api/chats/{peer_id}/read")
def mark_read(peer_id: int, current_user: dict = Depends(get_current_user)):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    # جيب آخر رسالة
    cursor.execute("""
        SELECT MAX(id) FROM messages
        WHERE (sender_id = ? AND receiver_id = ?)
           OR (sender_id = ? AND receiver_id = ?)
    """, (peer_id, current_user["id"], current_user["id"], peer_id))
    last_id = cursor.fetchone()[0] or 0
    
    cursor.execute("""
        INSERT INTO last_read (user_id, peer_id, message_id)
        VALUES (?, ?, ?)
        ON CONFLICT(user_id, peer_id) DO UPDATE SET message_id = ?
    """, (current_user["id"], peer_id, last_id, last_id))
    conn.commit()
    conn.close()
    return {"status": "success"}