class AppSettings {
  final int batchSize;
  final bool showPhotos;
  final bool showVideos;

  const AppSettings({
    required this.batchSize,
    required this.showPhotos,
    required this.showVideos,
  });

  factory AppSettings.defaultSettings() {
    return const AppSettings(
      batchSize: 15,
      showPhotos: true,
      showVideos: true,
    );
  }

  AppSettings copyWith({
    int? batchSize,
    bool? showPhotos,
    bool? showVideos,
  }) {
    return AppSettings(
      batchSize: batchSize ?? this.batchSize,
      showPhotos: showPhotos ?? this.showPhotos,
      showVideos: showVideos ?? this.showVideos,
    );
  }
}
