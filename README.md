# الرفيق - AlRafeeq Chat

تطبيق دردشة فوري يعمل على أندرويد والويب، مبني بـ Flutter مع دعم كامل للغة العربية (RTL).

---

## المتطلبات

| الأداة | الإصدار |
|--------|---------|
| Flutter SDK | >= 3.0.0 |
| Dart SDK | >= 3.0.0 |
| Android SDK | API 21+ |
| Gradle | 8.0+ |

---

## التشغيل محلياً

```bash
# تثبيت الحزم
flutter pub get

# تشغيل على أندرويد
flutter run

# تشغيل على الويب
flutter run -d chrome

# بناء ملف APK (Release)
flutter build apk --release

# بناء للويب (Release)
flutter build web --release
```

---

## هيكل المشروع

```
alrafeeq_flutter/
├── lib/
│   ├── main.dart                    # نقطة الدخول الرئيسية
│   ├── models/                      # نماذج البيانات
│   │   ├── user.dart                # نموذج المستخدم
│   │   ├── message.dart             # نموذج الرسالة
│   │   ├── chat.dart                # نموذج المحادثة
│   │   └── api_response.dart        # استجابة API عامة
│   ├── services/                    # الخدمات والشبكة
│   │   ├── api_service.dart         # اتصال REST API
│   │   ├── websocket_service.dart   # محادثات فورية WebSocket
│   │   └── auth_service.dart        # المصادقة والتخزين المحلي
│   ├── providers/                   # إدارة الحالة (Provider)
│   │   ├── auth_provider.dart       # حالة تسجيل الدخول
│   │   └── chat_provider.dart       # حالة المحادثات والرسائل
│   ├── screens/                     # شاشات التطبيق
│   │   ├── splash_screen.dart       # شاشة البداية
│   │   ├── auth_screen.dart         # تسجيل الدخول وإنشاء حساب
│   │   ├── home_screen.dart         # الشاشة الرئيسية
│   │   ├── chat_list_screen.dart    # قائمة المحادثات والبحث
│   │   └── chat_room_screen.dart    # غرفة الدردشة
│   └── utils/
│       └── date_formatter.dart      # تنسيق التاريخ بالعربي
├── android/                         # إعدادات أندرويد
├── web/                             # صفحة الويب (PWA)
├── assets/                          # الملفات الثابتة
├── pubspec.yaml                     # إعدادات الحزم
└── codemagic.yaml                   # ورك فلو Codemagic
```

---

## API Backend

| النوع | العنوان |
|-------|---------|
| REST API | `https://chat.alrafeeg.com/api` |
| WebSocket | `wss://chat.alrafeeg.com/ws/chat/{token}` |

### نقاط النهاية

| الطريقة | المسار | الوصف |
|---------|--------|-------|
| POST | `/api/login` | تسجيل الدخول |
| POST | `/api/register` | إنشاء حساب جديد |
| GET | `/api/chats` | قائمة المحادثات |
| GET | `/api/messages/{userId}` | رسائل محادثة |
| POST | `/api/messages/send` | إرسال رسالة (HTTP) |
| POST | `/api/users/search` | البحث عن مستخدمين |

---

## المميزات

- تسجيل دخول وإنشاء حساب جديد
- محادثات فورية عبر WebSocket مع إعادة اتصال تلقائي
- قائمة المحادثات مرتبة بأحدث رسالة
- بحث عن مستخدمين بالاسم أو ID
- إشعارات رسائل جديدة
- حفظ الإيميلات المحفوظة تلقائياً
- تصميم RTL عربي كامل بخط Tajawal
- دعم أندرويد + الويب (PWA)
- حالة اتصال WebSocket في الواجهة
- ذاكرة مؤقتة (cache) للمحادثات والرسائل

---

## الحزم المستخدمة

| الحزمة | الوظيفة |
|--------|---------|
| `provider` | إدارة الحالة |
| `http` | طلبات REST API |
| `web_socket_channel` | اتصال WebSocket |
| `shared_preferences` | التخزين المحلي |
| `google_fonts` | خط Tajawal |
| `intl` | تنسيق التواريخ |
| `flutter_local_notifications` | إشعارات |
| `connectivity_plus` | حالة الاتصال |
| `shimmer` | تأثيرات التحميل |

---

## البناء عبر Codemagic

الورك فلو جاهز في ملف `codemagic.yaml`:

```yaml
workflows:
  android-web-workflow:
    name: Build APK and Web
    max_build_duration: 60
    environment:
      flutter: stable
    scripts:
      - name: Get Flutter packages
        script: flutter pub get
      - name: Build Web
        script: flutter build web --release
      - name: Build APK
        script: flutter build apk --release
    artifacts:
      - build/app/outputs/flutter-apk/app-release.apk
      - build/web/**
```

يتم بناء APK ونسخة الويب تلقائياً عند كل push.

---

## الترخيص

هذا المشروع خاص وتطبيق الرفيق - جميع الحقوق محفوظة.
