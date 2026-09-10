import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

function randomInviteCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  return Array.from({ length: 6 }, () =>
    chars[Math.floor(Math.random() * chars.length)]
  ).join("");
}

export const createGroup = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in first.");
  }

  const solo = data?.solo === true;
  const name = (data?.name as string | undefined)?.trim();
  if (!solo && !name) {
    throw new functions.https.HttpsError("invalid-argument", "Group name is required.");
  }

  const uid = context.auth.uid;
  const inviteCode = solo ? null : randomInviteCode();

  const groupRef = db.collection("groups").doc();
  await db.runTransaction(async (tx) => {
    tx.set(groupRef, {
      name: name || "Solo",
      solo,
      inviteCode,
      memberUids: [uid],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(
      db.collection("users").doc(uid),
      { groupId: groupRef.id, solo, displayName: context.auth!.token.name ?? "" },
      { merge: true }
    );
  });

  return { groupId: groupRef.id, inviteCode, solo };
});

export const joinGroup = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in first.");
  }

  const inviteCode = data?.inviteCode as string | undefined;
  if (!inviteCode?.trim()) {
    throw new functions.https.HttpsError("invalid-argument", "Invite code is required.");
  }

  const uid = context.auth.uid;

  const snap = await db
    .collection("groups")
    .where("inviteCode", "==", inviteCode.trim().toUpperCase())
    .limit(1)
    .get();

  if (snap.empty) {
    throw new functions.https.HttpsError("not-found", "Invalid invite code.");
  }

  const groupDoc = snap.docs[0];
  const groupId = groupDoc.id;
  if (groupDoc.data()?.solo === true) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "This is a solo space and can’t be joined."
    );
  }

  await db.runTransaction(async (tx) => {
    tx.update(groupDoc.ref, {
      memberUids: admin.firestore.FieldValue.arrayUnion(uid),
    });
    tx.set(
      db.collection("users").doc(uid),
      { groupId, solo: false, displayName: context.auth!.token.name ?? "" },
      { merge: true }
    );
  });

  return { groupId, solo: false };
});

export const logEvent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in first.");
  }

  const taskId = (data?.taskId ?? data?.triggerId) as string | undefined;
  const groupId = data?.groupId as string | undefined;
  if (!groupId || !taskId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "groupId and taskId are required."
    );
  }

  const uid = context.auth.uid;

  const taskDoc = await db.collection("tasks").doc(taskId).get();
  if (!taskDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Task not found.");
  }

  const task = taskDoc.data() ?? {};
  if (task.groupId !== groupId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "This task is not part of your group."
    );
  }

  const groupDoc = await db.collection("groups").doc(groupId).get();
  if (!groupDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Group not found.");
  }

  const memberUids: string[] = groupDoc.data()?.memberUids ?? [];
  if (!memberUids.includes(uid)) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "You are not a member of this group."
    );
  }

  const notificationTitle = task.name ? `Apprch · ${task.name}` : "Apprch";
  const notificationBody =
    (task.notificationMessage as string | undefined)?.trim() ||
    `${task.icon ?? ""} ${task.name ?? "Update"}`.trim();

  await Promise.all([
    db.collection("events").add({
      groupId,
      taskId,
      loggedByUid: uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    }),
    taskDoc.ref.update({
      lastLoggedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLoggedByUid: uid,
      eventCount: admin.firestore.FieldValue.increment(1),
    }),
  ]);

  const recipients = memberUids.filter((id) => id !== uid);
  if (recipients.length === 0) return { sent: 0 };

  const userDocs = await Promise.all(
    recipients.map((id) => db.collection("users").doc(id).get())
  );

  const tokens: string[] = userDocs.flatMap(
    (doc) => (doc.data()?.fcmTokens ?? []) as string[]
  );
  if (tokens.length === 0) return { sent: 0 };

  const staleTokens: string[] = [];
  const chunks = chunkArray(tokens, 500);

  for (const chunk of chunks) {
    const response = await messaging.sendEachForMulticast({
      tokens: chunk,
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      apns: { payload: { aps: { sound: "default" } } },
      android: { notification: { sound: "default" } },
    });

    response.responses.forEach((res, i) => {
      if (
        !res.success &&
        res.error?.code === "messaging/registration-token-not-registered"
      ) {
        staleTokens.push(chunk[i]);
      }
    });
  }

  if (staleTokens.length > 0) {
    await Promise.all(
      userDocs.map((doc) => {
        const stale = staleTokens.filter((t) =>
          (doc.data()?.fcmTokens ?? []).includes(t)
        );
        if (stale.length === 0) return Promise.resolve();
        return doc.ref.update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...stale),
        });
      })
    );
  }

  return { sent: tokens.length - staleTokens.length };
});

function chunkArray<T>(arr: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
}
