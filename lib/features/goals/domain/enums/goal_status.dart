enum GoalStatus { active, completed, paused, archived }

extension GoalStatusX on GoalStatus {
  String get storageValue => switch (this) {
    GoalStatus.active => 'active',
    GoalStatus.completed => 'completed',
    GoalStatus.paused => 'paused',
    GoalStatus.archived => 'archived',
  };
}

abstract final class GoalStatusStorage {
  static GoalStatus fromStorage(String value) => switch (value) {
    'completed' => GoalStatus.completed,
    'paused' => GoalStatus.paused,
    'archived' => GoalStatus.archived,
    _ => GoalStatus.active,
  };
}
