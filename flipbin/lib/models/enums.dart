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
}
