# Accounts

Feature boundary for account aggregation, balances, and account settings.

## Layers

- `domain`: Account entity, value objects, repository contract, and use cases.
- `data`: Drift table, local data source, DTOs, mappers, and repository implementation.
- `application`: Riverpod providers for dependency injection and read use cases.
