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

export const createFamily = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in first.");
  }

  const name = data?.name as string | undefined;
  if (!name?.trim()) {
    throw new functions.https.HttpsError("invalid-argument", "Household name is required.");
  }

  const uid = context.auth.uid;
  const inviteCode = randomInviteCode();

  const familyRef = db.collection("families").doc();
  await db.runTransaction(async (tx) => {
    tx.set(familyRef, {
      name: name.trim(),
      inviteCode,
      memberUids: [uid],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(
      db.collection("users").doc(uid),
      { familyId: familyRef.id, displayName: context.auth!.token.name ?? "" },
      { merge: true }
    );
  });

  return { familyId: familyRef.id, inviteCode };
});

export const joinFamily = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in first.");
  }

  const inviteCode = data?.inviteCode as string | undefined;
  if (!inviteCode?.trim()) {
    throw new functions.https.HttpsError("invalid-argument", "Invite code is required.");
  }

  const uid = context.auth.uid;

  const snap = await db
    .collection("families")
    .where("inviteCode", "==", inviteCode.trim().toUpperCase())
    .limit(1)
    .get();

  if (snap.empty) {
    throw new functions.https.HttpsError("not-found", "Invalid invite code.");
  }

  const familyDoc = snap.docs[0];
  const familyId = familyDoc.id;

  await db.runTransaction(async (tx) => {
    tx.update(familyDoc.ref, {
      memberUids: admin.firestore.FieldValue.arrayUnion(uid),
    });
    tx.set(
      db.collection("users").doc(uid),
      { familyId, displayName: context.auth!.token.name ?? "" },
      { merge: true }
    );
  });

  return { familyId };
});

export const logEvent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in first.");
  }

  const triggerId = data?.triggerId as string | undefined;
  const familyId = data?.familyId as string | undefined;
  if (!familyId || !triggerId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "familyId and triggerId are required."
    );
  }

  const uid = context.auth.uid;

  const triggerDoc = await db.collection("triggers").doc(triggerId).get();
  if (!triggerDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Trigger not found.");
  }

  const trigger = triggerDoc.data() ?? {};
  if (trigger.familyId !== familyId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "This trigger is not part of your household."
    );
  }

  const familyDoc = await db.collection("families").doc(familyId).get();
  if (!familyDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Household not found.");
  }

  const memberUids: string[] = familyDoc.data()?.memberUids ?? [];
  if (!memberUids.includes(uid)) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "You are not a member of this household."
    );
  }

  const notificationTitle = trigger.name ? `Apprch · ${trigger.name}` : "Apprch";
  const notificationBody =
    (trigger.notificationMessage as string | undefined)?.trim() ||
    `${trigger.icon ?? ""} ${trigger.name ?? "Update"}`.trim();

  await Promise.all([
    db.collection("events").add({
      familyId,
      triggerId,
      triggeredByUid: uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    }),
    triggerDoc.ref.update({
      lastTriggeredAt: admin.firestore.FieldValue.serverTimestamp(),
      lastTriggeredByUid: uid,
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
