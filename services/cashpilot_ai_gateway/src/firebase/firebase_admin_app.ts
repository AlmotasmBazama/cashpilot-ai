import {
  applicationDefault,
  getApps,
  initializeApp,
  type App,
} from "firebase-admin/app";

const gatewayFirebaseAdminAppName = "cashpilot-ai-gateway";

export function getOrInitializeFirebaseAdminApp(projectId: string): App {
  return (
    getApps().find(
      (candidate) => candidate.name === gatewayFirebaseAdminAppName,
    ) ??
    initializeApp(
      {
        credential: applicationDefault(),
        projectId,
      },
      gatewayFirebaseAdminAppName,
    )
  );
}
