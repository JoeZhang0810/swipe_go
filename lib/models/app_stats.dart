import 'package:intl/intl.dart';

class AppStats {
  final int totalViewed;
  final int totalDeleted;
  final int spaceSaved;

  const AppStats({
    this.totalViewed = 0,
    this.totalDeleted = 0,
    this.spaceSaved = 0,
  });

  AppStats copyWith({
    int? totalViewed,
    int? totalDeleted,
    int? spaceSaved,
  }) {
    return AppStats(
      totalViewed: totalViewed ?? this.totalViewed,
      totalDeleted: totalDeleted ?? this.totalDeleted,
      spaceSaved: spaceSaved ?? this.spaceSaved,
    );
  }

  String get spaceSavedFormatted {
    if (spaceSaved < 1024) {
      return '${spaceSaved}B';
    } else if (spaceSaved < 1024 * 1024) {
      return '${(spaceSaved / 1024).toStringAsFixed(1)}KB';
    } else if (spaceSaved < 1024 * 1024 * 1024) {
      return '${(spaceSaved / (1024 * 1024)).toStringAsFixed(1)}MB';
    } else {
      return '${(spaceSaved / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
    }
  }
}
