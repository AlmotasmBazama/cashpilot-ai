/// The minimal immutable account projection required by Goals presentation.
///
/// Archived options remain available for existing linked-goal labels, while
/// the form decides which options may be selected for a new link.
final class GoalLinkedAccountOption {
  const GoalLinkedAccountOption({
    required this.id,
    required this.name,
    required this.isArchived,
  });

  final String id;
  final String name;
  final bool isArchived;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalLinkedAccountOption &&
          other.id == id &&
          other.name == name &&
          other.isArchived == isArchived;

  @override
  int get hashCode => Object.hash(id, name, isArchived);
}
