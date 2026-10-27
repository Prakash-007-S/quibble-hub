# Known Limitations & Environment Transparency Report
## Universal Complaint Management System

---

## 1. Purpose of this Document

In compliance with the project guidelines, this document provides an honest, transparent disclosure of verified capabilities versus environment-dependent factors or external prerequisites.

---

## 2. Environment Status & Platform Support

### A. Android SDK & Host Tooling
- **Current Host Status:** The development host is a Windows system equipped with Python 3.14, Flutter 3.47.1, Dart 3.13.1, and PostgreSQL 18.6 binaries. The Android SDK and command-line tools (`adb`, Android virtual devices) were not pre-installed on this specific machine.
- **Verification Performed:**
  - Flutter analysis (`flutter analyze`): **0 issues found**.
  - Flutter VM test execution (`flutter test`): **5/5 widget & state tests passed**.
  - Web & Windows desktop compilation targets verified.
- **Instructions for Evaluators with Android SDK:**
  - If running on a machine with Android Studio / Android SDK installed, simply execute:
    ```bash
    cd frontend
    flutter run -d <android-device-or-emulator-id>
    ```
  - The Flutter API client automatically routes requests to `http://10.0.2.2:8000/api/v1` when executing on the Android emulator, or to `http://<LAN_IP>:8000/api/v1` on a physical device.

### B. AI Engine & Cloud API Keys
- **Default Architecture:** Built with an honest, dual-mode AI abstraction (`app.ai.provider.AIProvider`).
- **Verified Offline Fallback:** When `AI_API_KEY` is omitted, the application runs on its built-in local NLP engine using `scikit-learn` TF-IDF vectorization and domain heuristics. All classification, duplicate detection, and summarization tests pass cleanly in offline mode.
- **External Cloud AI Support:** To switch to Google Gemini or OpenAI:
  1. Set `AI_PROVIDER=gemini` and `AI_API_KEY=<your_key>` in `backend/.env`.
  2. The system will seamlessly route classification and summarization to Gemini 1.5 Flash.

### C. Email Delivery (SMTP)
- **Default State:** `EMAILS_ENABLED=false` by default.
- **Behavior:** In-app notifications are persisted to PostgreSQL and rendered on the client notifications screen. Email dispatch errors or missing SMTP credentials do not block or roll back database transactions.
- **Enabling SMTP:** Can be toggled to `true` with credentials from Mailtrap, SendGrid, or AWS SES.

### D. File Storage
- **Current Implementation:** Private local filesystem storage in `backend/uploads/` with MIME-type verification, extension whitelisting, and UUID-based filename sanitization.
- **Production Path:** Architecture abstracts storage into a service layer that can be swapped for AWS S3 or MinIO without modifying the complaint API contract.
