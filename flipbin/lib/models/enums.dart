/// Enums for FlipBin inventory and expense tracking.
library;

/// Type of inventory item.
enum ItemType {
  game,
  dvd,
  bluray,
  cd,
  book,
  other;

  String get label {
    switch (this) {
      case ItemType.game:
        return 'Game';
      case ItemType.dvd:
        return 'DVD';
      case ItemType.bluray:
        return 'Blu-ray';
      case ItemType.cd:
        return 'CD';
      case ItemType.book:
        return 'Book';
      case ItemType.other:
        return 'Other';
    }
  }

  static ItemType fromLabel(String? label) {
    if (label == null || label.trim().isEmpty) return ItemType.other;
    final lower = label.trim().toLowerCase();
    for (final val in ItemType.values) {
      if (val.label.toLowerCase() == lower || val.name.toLowerCase() == lower) {
        return val;
      }
    }
    return ItemType.other;
  }

  /// Heuristic mapping from free-form category text (e.g. UPCitemdb
  /// "Electronics > Video Games > ...") to a FlipBin [ItemType].
  static ItemType fromCategory(String? category) {
    if (category == null || category.trim().isEmpty) return ItemType.other;
    final lower = category.trim().toLowerCase();

    if (lower.contains('blu-ray') ||
        lower.contains('bluray') ||
        lower.contains('blu ray')) {
      return ItemType.bluray;
    }
    if (lower.contains('dvd') || lower.contains('video > movies')) {
      return ItemType.dvd;
    }
    if (RegExp(r'\bcd\b').hasMatch(lower) ||
        lower.contains('compact disc') ||
        lower.contains('music >')) {
      return ItemType.cd;
    }
    if (lower.contains('video game') ||
        lower.contains('videogame') ||
        lower.contains('games') ||
        lower.contains('nintendo') ||
        lower.contains('playstation') ||
        lower.contains('xbox') ||
        lower.contains('software > games')) {
      return ItemType.game;
    }
    if (lower.contains('book') ||
        lower.contains('ebook') ||
        lower.contains('literature') ||
        lower.contains('media > books')) {
      return ItemType.book;
    }
    // Fall back to label/name match (e.g. category is literally "Game").
    return ItemType.fromLabel(category);
  }
}

/// Status of an inventory item.
enum ItemStatus {
  active,
  sold,
  personal;

  String get label {
    switch (this) {
      case ItemStatus.active:
        return 'Active';
      case ItemStatus.sold:
        return 'Sold';
      case ItemStatus.personal:
        return 'Personal';
    }
  }

  static ItemStatus fromLabel(String? label) {
    if (label == null || label.trim().isEmpty) return ItemStatus.active;
    final lower = label.trim().toLowerCase();
    for (final val in ItemStatus.values) {
      if (val.label.toLowerCase() == lower || val.name.toLowerCase() == lower) {
        return val;
      }
    }
    // Legacy / spreadsheet variants (e.g. "Personal Use", "Personal Item").
    if (lower.startsWith('personal')) {
      return ItemStatus.personal;
    }
    return ItemStatus.active;
  }
}

/// Type of business expense.
enum ExpenseType {
  shipping,
  equipment,
  software,
  travel,
  other;

  String get label {
    switch (this) {
      case ExpenseType.shipping:
        return 'Shipping';
      case ExpenseType.equipment:
        return 'Equipment';
      case ExpenseType.software:
        return 'Software';
      case ExpenseType.travel:
        return 'Travel';
      case ExpenseType.other:
        return 'Other';
    }
  }

  static ExpenseType fromLabel(String? label) {
    if (label == null || label.trim().isEmpty) return ExpenseType.other;
    final lower = label.trim().toLowerCase();
    for (final val in ExpenseType.values) {
      if (val.label.toLowerCase() == lower || val.name.toLowerCase() == lower) {
        return val;
      }
    }
    return ExpenseType.other;
  }
}
