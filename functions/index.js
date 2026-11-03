const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

/**
 * Sends a push notification to every member of a group except the one who
 * triggered it (so you never get notified about your own action).
 */
async function notifyGroup(groupId, excludeUid, title, body) {
  const groupSnap = await db.collection("groups").doc(groupId).get();
  const members = groupSnap.data()?.members || {};
  const uids = Object.keys(members).filter((uid) => uid !== excludeUid);
  if (uids.length === 0) return;

  const userRefs = uids.map((uid) => db.collection("users").doc(uid));
  const userDocs = await db.getAll(...userRefs);

  const tokens = [];
  for (const doc of userDocs) {
    const t = doc.data()?.fcmTokens;
    if (Array.isArray(t)) tokens.push(...t);
  }
  if (tokens.length === 0) return;

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: {title, body},
    data: {groupId},
  });

  // Drop tokens that are no longer valid (app uninstalled, etc.) so the
  // array doesn't grow stale forever.
  const staleTokens = [];
  response.responses.forEach((r, i) => {
    if (!r.success && r.error?.code === "messaging/registration-token-not-registered") {
      staleTokens.push(tokens[i]);
    }
  });
  if (staleTokens.length > 0) {
    const {FieldValue} = require("firebase-admin/firestore");
    await Promise.all(
        userDocs
            .filter((doc) => (doc.data()?.fcmTokens || []).some((t) => staleTokens.includes(t)))
            .map((doc) =>
              doc.ref.update({fcmTokens: FieldValue.arrayRemove(...staleTokens)}),
            ),
    );
  }
}

exports.onItemAdded = onDocumentCreated(
    "groups/{groupId}/items/{itemId}",
    async (event) => {
      const item = event.data?.data();
      if (!item) return;
      await notifyGroup(
          event.params.groupId,
          item.addedBy,
          "OurShelf",
          `${item.addedByName} added ${item.name} to the list`,
      );
    },
);

exports.onItemUpdated = onDocumentUpdated(
    "groups/{groupId}/items/{itemId}",
    async (event) => {
      const before = event.data?.before.data();
      const after = event.data?.after.data();
      if (!before || !after) return;
      if (before.status !== "bought" && after.status === "bought") {
        await notifyGroup(
            event.params.groupId,
            after.boughtByUid,
            "OurShelf",
            `${after.paidByName || after.addedByName} bought ${after.name}`,
        );
      }
    },
);
