import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import '../models/media_item.dart';
import '../providers/app_providers.dart';
import '../widgets/delete_confirmation_sheet.dart';

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
    setState(() {
      _isLoading = false;
    });
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
    // 第一张无效
    if (currentIndex > 0) {
      ref.read(currentIndexProvider.notifier).state = currentIndex - 1;
      _pauseCurrentVideo();
      // 更新已查看统计
      ref.read(statsProvider.notifier).incrementViewed();
    }
  }

  void _goToNext() {
    final mediaList = ref.read(mediaListProvider);
    final currentIndex = ref.read(currentIndexProvider);
    if (currentIndex < mediaList.length - 1) {
      ref.read(currentIndexProvider.notifier).state = currentIndex + 1;
      _pauseCurrentVideo();
      // 更新已查看统计
      ref.read(statsProvider.notifier).incrementViewed();
    } else {
      // 最后一张左滑 → 直接弹出删除确认弹层
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

  void _showMediaDetails(MediaItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '详细信息',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('文件名', item.title),
            _buildDetailRow('类型', item.isVideo ? '视频' : '图片'),
            _buildDetailRow('尺寸', '${item.width} x ${item.height}'),
            _buildDetailRow(
              '创建时间',
              item.createDateTime.toString().substring(0, 19),
            ),
            if (item.relativePath != null)
              _buildDetailRow('路径', item.relativePath!),
            if (item.latitude != null && item.longitude != null) ...[
              _buildDetailRow('纬度', item.latitude!),
              _buildDetailRow('经度', item.longitude!),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaList = ref.watch(mediaListProvider);
    final currentIndex = ref.watch(currentIndexProvider);
    final notifier = ref.read(mediaListProvider.notifier);
    final markedCount = notifier.markedForDeletion.length;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A1A),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (mediaList.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A1A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text(
            '暂无内容',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    final currentItem = mediaList[currentIndex];
    final progress = (currentIndex + 1) / mediaList.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Stack(
        children: [
          // 主要内容区域 - 手势控制
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _swipeOffsetX += details.delta.dx;
              });
            },
            onHorizontalDragEnd: (details) {
              if (_swipeOffsetX > 50) {
                // 右滑 → 上一条（第一张无效）
                _goToPrevious();
              } else if (_swipeOffsetX < -50) {
                // 左滑 → 下一条
                _goToNext();
              }
              setState(() {
                _swipeOffsetX = 0;
              });
            },
            onVerticalDragUpdate: (details) {
              setState(() {
                _swipeOffsetY += details.delta.dy;
                _showDeleteHint = _swipeOffsetY < -30;
              });
            },
            onVerticalDragEnd: (details) {
              if (_swipeOffsetY < -100) {
                // 上滑 → 标记删除 + 切换下一条
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

          // 顶部红色删除提示
          if (_showDeleteHint)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: MediaQuery.of(context).padding.top + 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFEF4444).withOpacity(0.8),
                      const Color(0xFFEF4444).withOpacity(0.0),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete,
                          color: Colors.white.withOpacity(0.9),
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '上滑删除',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 顶部进度条和导航
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // 白色渐变进度条
                Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1),
                    color: Colors.grey[800],
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1),
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xF2FFFFFF), // 0.95 opacity
                            Color(0x66FFFFFF), // 0.4 opacity
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // 返回按钮和删除计数
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        '${currentIndex + 1} / ${mediaList.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      // 删除计数按钮 → 弹出删除确认弹层
                      GestureDetector(
                        onTap: markedCount > 0 ? _showDeleteConfirmation : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: markedCount > 0
                                ? const Color(0xFFEF4444).withOpacity(0.8)
                                : Colors.grey[800],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$markedCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 底部操作按钮
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 详情按钮 - 白色渐变
                  GestureDetector(
                    onTap: () => _showMediaDetails(currentItem),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xF2FFFFFF), // 0.95 opacity
                            Color(0x66FFFFFF), // 0.4 opacity
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFF0A0A1A),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '详情',
                            style: TextStyle(
                              color: Color(0xFF0A0A1A),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 左右滑动提示 - 第一张时显示左滑提示
          if (currentIndex == 0)
            Positioned(
              left: 16,
              top: MediaQuery.of(context).size.height / 2 - 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chevron_left,
                  color: Colors.white54,
                  size: 24,
                ),
              ),
            ),
        ],
      ),
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
                // 播放按钮
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
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                // 点击视频区域暂停
                if (isPlaying)
                  GestureDetector(
                    onTap: () => _togglePlay(item),
                    child: Container(
                      color: Colors.transparent,
                    ),
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
