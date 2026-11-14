enum SyncEntityType {
  account,
  transaction,
  category,
  payee,
  budget,
  goal,
  exchangeRate,
  settings,
}

enum SyncOperationType { upsert, delete }

enum SyncStatus { pending, synced, failed, deleted }
