import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import '../models/media_item.dart';
import '../providers/app_providers.dart';
import '../widgets/delete_confirmation_sheet.dart';
import '../widgets/media_detail_sheet.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  bool _isLoading = true;
  final Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, bool> _isPlaying = {};
  double _swipeOffsetX = 0;
  double _swipeOffsetY = 0;
  bool _showDeleteHint = false;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  @override
  void dispose() {
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMedia() async {
    final settings = ref.read(settingsProvider);
    await ref.read(mediaListProvider.notifier).loadRandomMedia(
          count: settings.batchSize,
          includePhotos: settings.showPhotos,
          includeVideos: settings.showVideos,
        );
    setState(() { _isLoading = false; });
  }

  Future<VideoPlayerController> _getVideoController(MediaItem item) async {
    if (_videoControllers.containsKey(item.id)) {
      return _videoControllers[item.id]!;
    }

    final file = await item.entity.file;
    if (file == null) throw Exception('无法获取视频文件');

    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    _videoControllers[item.id] = controller;
    _isPlaying[item.id] = false;
    return controller;
  }

  void _togglePlay(MediaItem item) async {
    final controller = await _getVideoController(item);
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        _isPlaying[item.id] = false;
      } else {
        controller.play();
        _isPlaying[item.id] = true;
      }
    });
  }

  void _goToPrevious() {
    final currentIndex = ref.read(currentIndexProvider);
    if (currentIndex > 0) {
      ref.read(currentIndexProvider.notifier).state = currentIndex - 1;
      _pauseCurrentVideo();
      ref.read(statsProvider.notifier).incrementViewed();
    }
  }

  void _goToNext() {
    final mediaList = ref.read(mediaListProvider);
    final currentIndex = ref.read(currentIndexProvider);
    if (currentIndex < mediaList.length - 1) {
      ref.read(currentIndexProvider.notifier).state = currentIndex + 1;
      _pauseCurrentVideo();
      ref.read(statsProvider.notifier).incrementViewed();
    } else {
      _showDeleteConfirmation();
    }
  }

  void _pauseCurrentVideo() {
    final mediaList = ref.read(mediaListProvider);
    final currentIndex = ref.read(currentIndexProvider);
    if (currentIndex < mediaList.length) {
      final item = mediaList[currentIndex];
      if (item.isVideo && _videoControllers.containsKey(item.id)) {
        _videoControllers[item.id]!.pause();
        _isPlaying[item.id] = false;
      }
    }
  }

  void _markForDeleteAndNext() {
    final mediaList = ref.read(mediaListProvider);
    final currentIndex = ref.read(currentIndexProvider);
    if (currentIndex < mediaList.length) {
      final item = mediaList[currentIndex];
      ref.read(mediaListProvider.notifier).markForDeletion(item.id);
      _goToNext();
    }
  }

  void _showDeleteConfirmation() {
    final markedItems = ref.read(mediaListProvider.notifier).markedForDeletion;
    if (markedItems.isNotEmpty) {
      showDeleteConfirmationSheet(context, markedItems);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaList = ref.watch(mediaListProvider);
    final currentIndex = ref.watch(currentIndexProvider);
    final notifier = ref.read(mediaListProvider.notifier);
    final markedCount = notifier.markedForDeletion.length;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (mediaList.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('暂无内容',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      );
    }

    final currentItem = mediaList[currentIndex];
    final totalCount = mediaList.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 主要内容 - 手势区域
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() { _swipeOffsetX += details.delta.dx; });
            },
            onHorizontalDragEnd: (details) {
              if (_swipeOffsetX > 50) {
                _goToPrevious();
              } else if (_swipeOffsetX < -50) {
                _goToNext();
              }
              setState(() { _swipeOffsetX = 0; });
            },
            onVerticalDragUpdate: (details) {
              setState(() {
                _swipeOffsetY += details.delta.dy;
                _showDeleteHint = _swipeOffsetY < -30;
              });
            },
            onVerticalDragEnd: (details) {
              if (_swipeOffsetY < -100) {
                _markForDeleteAndNext();
              }
              setState(() {
                _swipeOffsetY = 0;
                _showDeleteHint = false;
              });
            },
            child: Transform.translate(
              offset: Offset(_swipeOffsetX, _swipeOffsetY),
              child: Center(
                child: _buildMediaContent(currentItem),
              ),
            ),
          ),

          // 上划删除红色渐变提示
          if (_showDeleteHint)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: MediaQuery.of(context).padding.top + 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x80C82828),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '↑ 上划删除',
                        style: TextStyle(
                          color: Colors.red.shade300,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 顶部分段进度条 + 删除计数
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // 分段进度条
                _buildSegmentedProgress(totalCount, currentIndex),
                const SizedBox(height: 12),
                // 删除计数徽章 (右对齐)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (markedCount > 0)
                      GestureDetector(
                        onTap: _showDeleteConfirmation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xD9DC3C3C),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline,
                                  color: Colors.white, size: 10),
                              const SizedBox(width: 4),
                              Text(
                                '$markedCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 左右滑动提示箭头
          Positioned(
            top: 0,
            bottom: 80,
            left: 10,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.chevron_left,
                    color: Colors.white38, size: 18),
              ),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 80,
            right: 10,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.chevron_right,
                    color: Colors.white38, size: 18),
              ),
            ),
          ),

          // 底部信息按钮 (圆形，仅图标)
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Center(
              child: GestureDetector(
                onTap: () => showMediaDetailSheet(context, currentItem),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedProgress(int total, int current) {
    return Row(
      children: List.generate(total, (i) {
        final isDone = i < current;
        final isCurrent = i == current;
        return Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isDone
                  ? Colors.white.withOpacity(0.8)
                  : Colors.white.withOpacity(0.25),
            ),
            child: isCurrent
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.4,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildMediaContent(MediaItem item) {
    if (item.isImage) {
      return FutureBuilder<Uint8List?>(
        future: item.entity.thumbnailDataWithSize(
          ThumbnailSize(
            MediaQuery.of(context).size.width.toInt(),
            MediaQuery.of(context).size.height.toInt(),
          ),
          quality: 90,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            );
          }
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
      );
    } else {
      return FutureBuilder<VideoPlayerController>(
        future: _getVideoController(item),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final controller = snapshot.data!;
            final isPlaying = _isPlaying[item.id] ?? false;
            return Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
                if (!isPlaying)
                  GestureDetector(
                    onTap: () => _togglePlay(item),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow,
                          color: Colors.white, size: 48),
                    ),
                  ),
                if (isPlaying)
                  GestureDetector(
                    onTap: () => _togglePlay(item),
                    child: Container(color: Colors.transparent),
                  ),
              ],
            );
          }
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
      );
    }
  }
}
