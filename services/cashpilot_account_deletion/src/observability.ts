export type AccountDeletionLogStage =
  | "requestReceived"
  | "authVerified"
  | "appCheckVerified"
  | "proofVerified"
  | "deletionStarted"
  | "recursiveDeleteCompleted"
  | "verificationStarted"
  | "verificationCompleted"
  | "responseSent";

export interface SafeAccountDeletionLogEvent {
  readonly correlationId: string;
  readonly operationId?: string;
  readonly serviceRevision: string;
  readonly stage: AccountDeletionLogStage;
  readonly durationMs: number;
  readonly attempt: number;
  readonly documentCount?: number;
  readonly resultCode?: string;
  readonly safeErrorClass?: string;
  readonly httpStatus?: number;
  readonly retryable?: boolean;
}

export interface SafeAccountDeletionLogSink {
  write(event: SafeAccountDeletionLogEvent): void;
}

export class ConsoleSafeAccountDeletionLogSink
  implements SafeAccountDeletionLogSink
{
  write(event: SafeAccountDeletionLogEvent): void {
    console.log(
      JSON.stringify({
        event: "cashpilotAccountDeletion",
        ...event,
      }),
    );
  }
}

export function safeServiceRevision(
  env: NodeJS.ProcessEnv = process.env,
): string {
  const candidate = env.K_REVISION?.trim() ?? "";
  return /^[a-z0-9][a-z0-9-]{0,62}$/u.test(candidate)
    ? candidate
    : "local";
}
