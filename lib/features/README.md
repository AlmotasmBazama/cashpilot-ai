# Features

This project uses a feature-first Clean Architecture layout. Each finance feature should own its `data`, `domain`, `application`, and `presentation` layers inside its feature folder.

Keep cross-cutting infrastructure in `core/` and reusable UI in `shared/`.
