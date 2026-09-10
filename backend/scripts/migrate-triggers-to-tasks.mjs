/**
 * Copy Firestore `triggers` → `tasks` and add Task field names on events.
 *
 * Existing `triggers` documents are left in place as a backup.
 * Run from backend/functions so firebase-admin is available:
 *
 *   cd backend/functions
 *   node ../scripts/migrate-triggers-to-tasks.mjs
 */
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

initializeApp({ credential: applicationDefault(), projectId: "fresh-scoop" });
const db = getFirestore();

async function migrateTasks() {
  const snap = await db.collection("triggers").get();
  let copied = 0;
  for (const doc of snap.docs) {
    const data = { ...doc.data() };
    if (data.lastTriggeredAt != null && data.lastLoggedAt == null) {
      data.lastLoggedAt = data.lastTriggeredAt;
    }
    if (data.lastTriggeredByUid != null && data.lastLoggedByUid == null) {
      data.lastLoggedByUid = data.lastTriggeredByUid;
    }
    await db.collection("tasks").doc(doc.id).set(data, { merge: true });
    copied += 1;
  }
  return copied;
}

async function migrateEvents() {
  const snap = await db.collection("events").get();
  let updated = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    const patch = {};
    if (data.taskId == null && data.triggerId != null) patch.taskId = data.triggerId;
    if (data.loggedByUid == null && data.triggeredByUid != null) {
      patch.loggedByUid = data.triggeredByUid;
    }
    if (Object.keys(patch).length === 0) continue;
    await doc.ref.update(patch);
    updated += 1;
  }
  return updated;
}

const tasks = await migrateTasks();
const events = await migrateEvents();
console.log(`Copied ${tasks} task(s). Updated ${events} event(s).`);
console.log("Left the triggers collection in place as a backup.");
