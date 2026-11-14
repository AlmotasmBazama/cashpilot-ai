import type { Firestore } from "firebase-admin/firestore";

export async function isFirebaseUserTreeEmpty(
  firestore: Firestore,
  uid: string,
): Promise<boolean> {
  const user = firestore.collection("users").doc(uid);
  const [root, remainingCollections] = await Promise.all([
    user.get(),
    user.listCollections(),
  ]);
  return !root.exists && remainingCollections.length === 0;
}
