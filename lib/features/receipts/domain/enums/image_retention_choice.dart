enum ImageRetentionChoice { deleteAfterExtraction, keepLocally, undecided }

extension ImageRetentionChoiceX on ImageRetentionChoice {
  String get storageValue {
    return switch (this) {
      ImageRetentionChoice.deleteAfterExtraction => 'delete_after_extraction',
      ImageRetentionChoice.keepLocally => 'keep_locally',
      ImageRetentionChoice.undecided => 'undecided',
    };
  }
}

abstract final class ImageRetentionChoiceMapper {
  static ImageRetentionChoice fromStorage(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('-', '_');
    return ImageRetentionChoice.values.firstWhere(
      (choice) =>
          choice.storageValue == normalized || choice.name == normalized,
      orElse: () => ImageRetentionChoice.undecided,
    );
  }
}
