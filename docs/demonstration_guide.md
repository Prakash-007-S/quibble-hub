# Evaluator Demonstration Guide
## Quibble Hub — Universal Complaint Management System
### Step-by-Step Viva & Final-Year Engineering Project Evaluation Script

---

## 1. Quick Launch Checklist

Before starting the viva presentation, verify that the services are active:

### Terminal 1 — Start PostgreSQL (Port 5434)
```powershell
python scripts/run_postgres.py
```
*(If already running in background, output will indicate `PostgreSQL is ready`)*

### Terminal 2 — Start FastAPI Backend (Port 8000)
```powershell
python scripts/run_backend.py
```
*Backend API docs will be live at: [http://localhost:8000/docs](http://localhost:8000/docs)*

### Terminal 3 — Launch Flutter Application
```powershell
cd frontend
flutter run -d chrome
# OR for Windows Desktop:
# flutter run -d windows
# OR for Android Emulator:
# flutter run -d emulator-5554
```

---

## 2. Demo User Credentials (One-Tap Quick Fill)

The login screen features quick-fill buttons for instant switching between user personas:

| Persona | Organization | Role | Email | Password |
|---|---|---|---|---|
| **Complainant (Student)** | Sengunthar Engineering College (`COLLEGE`) | `COMPLAINANT` | `student.apex@complaintsystem.org` | `DemoPass@123` |
| **Staff / Handler** | Sengunthar Engineering College (`COLLEGE`) | `STAFF` | `staff.apex@complaintsystem.org` | `DemoPass@123` |
| **Dept Manager** | Sengunthar Engineering College (`COLLEGE`) | `MANAGER` | `manager.apex@complaintsystem.org` | `DemoPass@123` |
| **Org Administrator** | Sengunthar Engineering College (`COLLEGE`) | `ADMIN` | `orgadmin.apex@complaintsystem.org` | `DemoPass@123` |
| **Dual-Org User** | Sengunthar & SwiftLogistics | `COMPLAINANT` | `multi.user@complaintsystem.org` | `DemoPass@123` |
| **Platform Administrator** | System-Wide | `PLATFORM_ADMIN` | `admin@complaintsystem.org` | `Admin@12345` |

---

## 3. Recommended 6-Phase Viva Demonstration Script

### Phase 1: Complainant Experience & AI-Assisted Creation
1. Open the application. Tap the **"Student"** quick-fill button on the login screen and tap **Sign In**.
2. Notice the **Role-Adaptive Dashboard** showing total grievances, active in-progress items, and resolved counts.
3. Tap the **"+" (FAB)** button to file a new complaint.
4. In the title, type:
   > `Severe internet disruption in Computer Science Lab 4`
5. In the description, type:
   > `All workstations have lost network connectivity during the operating systems practical examination.`
6. **Showcase AI Classification:**
   - Tap **"Get AI Suggestion"**.
   - Point out that the AI accurately categorizes this as **"IT & Lab Equipment"**, routes it to **"Campus IT & Lab Services"**, sets priority to **"HIGH"**, and explains its reasoning.
   - Tap **"Apply AI Suggestions"** — form fields update automatically.
7. **Showcase Real-Time Duplicate Detection:**
   - Notice the **"Possible Duplicates Detected"** amber banner appearing below the description.
   - The engine flags `APEX-2026-0001` (*"Campus Wi-Fi & Network Outage"*) with an 85%+ similarity score!
8. Tap **"Submit Complaint"**.
   - Emphasize the collision-safe unique tracking number generated: e.g. `APEX-2026-0008`.

---

### Phase 2: Staff Investigation & Workflow Transition
1. Log out via Profile tab.
2. Tap the **"Staff"** button on the login screen (`staff.apex@complaintsystem.org`).
3. Notice the **Staff Dashboard**:
   - Displays department queues, assigned cases, and overdue SLA warnings.
4. Tap the **Complaints** tab.
5. Select the Wi-Fi or lab complaint.
6. **Showcase Internal Notes vs. Public Comments:**
   - Add a comment: *"Network technician dispatched to inspect Switch Rack B."*
   - Toggle **"Internal Note (Staff only)"** ON. Post the note.
7. **Showcase Valid State Transitions:**
   - Tap **"Update Status"**.
   - Change status to **"IN_PROGRESS"**. Notice the live timeline updates with actor name, timestamp, and audit history.
8. Transition to **"RESOLVED"**:
   - System prompts for a resolution summary.
   - Input: *"Replaced faulty PoE injector on core switch; network connectivity restored."*
   - Status changes to **RESOLVED**.

---

### Phase 3: Complainant Feedback & Confirmation
1. Log back in as **"Student"** (`student.apex@complaintsystem.org`).
2. Open the newly resolved complaint.
3. Notice that the staff's **internal note is strictly hidden** from the student, while the resolution summary is prominent.
4. Tap **"Rate & Close Resolution"**:
   - Provide a 5-star rating and comment: *"Fast resolution, thank you!"*
   - Tap **Confirm Outcome**. Status smoothly transitions to **CLOSED**.

---

### Phase 4: Multi-Tenant Switching
1. Tap the **"Dual Org"** login button (`multi.user@complaintsystem.org`).
2. Point to the top AppBar displaying **"Sengunthar Engineering College"**.
3. Tap the **Switch** icon in the AppBar.
4. Select **"SwiftLogistics Solutions (BUSINESS)"**.
5. Observe:
   - The complaints instantly change to commercial supply chain grievances (e.g. *Damaged Refrigerated Parcel*).
   - Zero data leakage occurs between the college and the logistics company.

---

### Phase 5: Manager / Administrator Live Analytics
1. Log in as **"Org Admin"** (`orgadmin.apex@complaintsystem.org`).
2. Review the **Executive Analytics Dashboard**:
   - Real-time resolution rates calculated from PostgreSQL.
   - Department breakdown bar distribution (IT vs. Facilities vs. Academics).
   - SLA breach counters.
3. Show the **OpenAPI Interactive Documentation**:
   - Open `http://localhost:8000/docs` in the browser.
   - Point out all 37 documented endpoints and the tenant header requirement.

---

### Phase 6: Automated Test Verification
Run the automated test suites live to prove robustness:
1. `python -m pytest tests/ -v` (18/18 passing in <3 seconds).
2. `flutter test` (5/5 passing).
3. `flutter analyze` (0 issues).
