import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../models/app_settings.dart';
import '../models/app_stats.dart';

// 应用设置
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings.defaultSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      batchSize: prefs.getInt('batchSize') ?? 15,
      showPhotos: prefs.getBool('showPhotos') ?? true,
      showVideos: prefs.getBool('showVideos') ?? true,
    );
  }

  Future<void> updateSettings({
    int? batchSize,
    bool? showPhotos,
    bool? showVideos,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (batchSize != null) {
      await prefs.setInt('batchSize', batchSize);
    }
    if (showPhotos != null) {
      await prefs.setBool('showPhotos', showPhotos);
    }
    if (showVideos != null) {
      await prefs.setBool('showVideos', showVideos);
    }
    
    state = state.copyWith(
      batchSize: batchSize,
      showPhotos: showPhotos,
      showVideos: showVideos,
    );
  }
}

// 应用统计
final statsProvider = StateNotifierProvider<StatsNotifier, AppStats>((ref) {
  return StatsNotifier();
});

class StatsNotifier extends StateNotifier<AppStats> {
  StatsNotifier() : super(const AppStats()) {
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppStats(
      totalViewed: prefs.getInt('totalViewed') ?? 0,
      totalDeleted: prefs.getInt('totalDeleted') ?? 0,
      spaceSaved: prefs.getInt('spaceSaved') ?? 0,
    );
  }

  Future<void> incrementViewed() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = state.totalViewed + 1;
    await prefs.setInt('totalViewed', newValue);
    state = state.copyWith(totalViewed: newValue);
  }

  Future<void> addDeleted(int count, int space) async {
    final prefs = await SharedPreferences.getInstance();
    final newDeleted = state.totalDeleted + count;
    final newSpace = state.spaceSaved + space;
    await prefs.setInt('totalDeleted', newDeleted);
    await prefs.setInt('spaceSaved', newSpace);
    state = state.copyWith(
      totalDeleted: newDeleted,
      spaceSaved: newSpace,
    );
  }
}

// 媒体列表
final mediaListProvider = StateNotifierProvider<MediaListNotifier, List<MediaItem>>((ref) {
  return MediaListNotifier();
});

class MediaListNotifier extends StateNotifier<List<MediaItem>> {
  MediaListNotifier() : super([]);

  List<MediaItem> _allMedia = [];
  List<MediaItem> _markedForDeletion = [];

  List<MediaItem> get markedForDeletion => _markedForDeletion;

  Future<void> loadRandomMedia({
    required int count,
    required bool includePhotos,
    required bool includeVideos,
  }) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      state = [];
      return;
    }

    final List<AssetEntity> assets = [];
    
    if (includePhotos) {
      final photoResult = await PhotoManager.getAssetListPaged(
        type: RequestType.image,
        page: 0,
        pageCount: count * 2,
      );
      assets.addAll(photoResult);
    }
    
    if (includeVideos) {
      final videoResult = await PhotoManager.getAssetListPaged(
        type: RequestType.video,
        page: 0,
        pageCount: count * 2,
      );
      assets.addAll(videoResult);
    }

    assets.shuffle();
    final selectedAssets = assets.take(count).toList();
    
    _allMedia = selectedAssets.map((asset) => MediaItem.fromAssetEntity(asset)).toList();
    state = List.from(_allMedia);
  }

  Future<void> loadPreviewPhotos() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) return;

    final result = await PhotoManager.getAssetListPaged(
      type: RequestType.image,
      page: 0,
      pageCount: 10,
    );
    
    result.shuffle();
    _allMedia = result.take(3).map((asset) => MediaItem.fromAssetEntity(asset)).toList();
    state = List.from(_allMedia);
  }

  void markForDeletion(String id) {
    final item = _allMedia.firstWhere((m) => m.id == id);
    if (!_markedForDeletion.any((m) => m.id == id)) {
      _markedForDeletion.add(item);
    }
  }

  void unmarkForDeletion(String id) {
    _markedForDeletion.removeWhere((m) => m.id == id);
  }

  void toggleMarkForDeletion(String id) {
    if (_markedForDeletion.any((m) => m.id == id)) {
      unmarkForDeletion(id);
    } else {
      markForDeletion(id);
    }
  }

  bool isMarkedForDeletion(String id) {
    return _markedForDeletion.any((m) => m.id == id);
  }

  Future<void> deleteMarkedItems() async {
    final ids = _markedForDeletion.map((m) => m.id).toList();
    await PhotoManager.editor.deleteWithIds(ids);
    _markedForDeletion.clear();
  }

  void clear() {
    _allMedia = [];
    _markedForDeletion = [];
    state = [];
  }
}

// 当前浏览索引
final currentIndexProvider = StateProvider<int>((ref) => 0);
