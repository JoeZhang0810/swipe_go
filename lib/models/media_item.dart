import 'package:photo_manager/photo_manager.dart';

class MediaItem {
  final String id;
  final String title;
  final DateTime createDateTime;
  final int width;
  final int height;
  final int size;
  final String? relativePath;
  final String? latitude;
  final String? longitude;
  final AssetType type;
  final AssetEntity entity;

  MediaItem({
    required this.id,
    required this.title,
    required this.createDateTime,
    required this.width,
    required this.height,
    required this.size,
    this.relativePath,
    this.latitude,
    this.longitude,
    required this.type,
    required this.entity,
  });

  factory MediaItem.fromAssetEntity(AssetEntity entity) {
    return MediaItem(
      id: entity.id,
      title: entity.title ?? '',
      createDateTime: entity.createDateTime,
      width: entity.width,
      height: entity.height,
      size: 0,
      relativePath: entity.relativePath,
      latitude: entity.latitude?.toString(),
      longitude: entity.longitude?.toString(),
      type: entity.type,
      entity: entity,
    );
  }

  bool get isVideo => type == AssetType.video;
  bool get isImage => type == AssetType.image;
}
