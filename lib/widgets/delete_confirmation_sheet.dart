import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_item.dart';
import '../providers/app_providers.dart';
import '../screens/launch_screen.dart';

// 选中状态管理
final selectedItemsProvider = StateNotifierProvider<SelectedItemsNotifier, Set<String>>((ref) {
  return SelectedItemsNotifier();
});

class SelectedItemsNotifier extends StateNotifier<Set<String>> {
  SelectedItemsNotifier() : super({});

  void initialize(List<MediaItem> items) {
    state = items.map((item) => item.id).toSet();
  }

  void toggle(String id) {
    if (state.contains(id)) {
      state = {...state}..remove(id);
    } else {
      state = {...state, id};
    }
  }

  bool isSelected(String id) => state.contains(id);

  void clear() => state = {};
}

class DeleteConfirmationSheet extends ConsumerStatefulWidget {
  final List<MediaItem> itemsToDelete;

  const DeleteConfirmationSheet({
    super.key,
    required this.itemsToDelete,
  });

  @override
  ConsumerState<DeleteConfirmationSheet> createState() => _DeleteConfirmationSheetState();
}

class _DeleteConfirmationSheetState extends ConsumerState<DeleteConfirmationSheet> {
  final Map<String, Uint8List?> _thumbnails = {};
  bool _isLoadingThumbnails = true;

  @override
  void initState() {
    super.initState();
    // 初始化选中状态 - 默认全部选中
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedItemsProvider.notifier).initialize(widget.itemsToDelete);
    });
    _loadThumbnails();
  }

  Future<void> _loadThumbnails() async {
    for (final item in widget.itemsToDelete) {
      final thumbData = await item.entity.thumbnailDataWithSize(
        const ThumbnailSize(200, 200),
        quality: 80,
      );
      if (mounted) {
        setState(() {
          _thumbnails[item.id] = thumbData;
        });
      }
    }
    if (mounted) {
      setState(() {
        _isLoadingThumbnails = false;
      });
    }
  }

  void _onCancel() {
    ref.read(selectedItemsProvider.notifier).clear();
    // 返回启动页
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LaunchScreen()),
      (route) => false,
    );
  }

  Future<void> _onConfirmDelete() async {
    final selectedIds = ref.read(selectedItemsProvider);
    
    if (selectedIds.isEmpty) {
      // 没有选择任何项目，直接返回
      _onCancel();
      return;
    }

    // 请求相册权限（会触发系统弹窗）
    final permission = await PhotoManager.requestPermissionExtend();
    
    if (!permission.isAuth) {
      // 用户拒绝了权限
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('需要相册权限才能删除照片'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    // 执行删除操作
    try {
      await PhotoManager.editor.deleteWithIds(selectedIds.toList());
      
      // 更新统计信息
      final deletedCount = selectedIds.length;
      int totalSpace = 0;
      for (final item in widget.itemsToDelete) {
        if (selectedIds.contains(item.id)) {
          totalSpace += item.size;
        }
      }
      
      await ref.read(statsProvider.notifier).addDeleted(deletedCount, totalSpace);
      
      // 清空标记列表
      ref.read(mediaListProvider.notifier).clear();
      ref.read(selectedItemsProvider.notifier).clear();

      if (mounted) {
        // 显示删除成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已成功删除 $deletedCount 个项目'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 返回启动页
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LaunchScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIds = ref.watch(selectedItemsProvider);
    final selectedCount = selectedIds.length;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部标题栏
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '确认删除 ($selectedCount/${widget.itemsToDelete.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 媒体列表
                Flexible(
                  child: widget.itemsToDelete.isEmpty
                      ? const Center(
                          child: Text(
                            '没有要删除的项目',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: widget.itemsToDelete.length,
                          itemBuilder: (context, index) {
                            final item = widget.itemsToDelete[index];
                            final isSelected = ref.watch(selectedItemsProvider.notifier).isSelected(item.id);
                            final thumbData = _thumbnails[item.id];

                            return GestureDetector(
                              onTap: () {
                                ref.read(selectedItemsProvider.notifier).toggle(item.id);
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // 缩略图
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: thumbData != null
                                        ? Image.memory(
                                            thumbData,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            color: Colors.grey[800],
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                                              ),
                                            ),
                                          ),
                                  ),

                                  // 视频标识
                                  if (item.isVideo)
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(
                                          Icons.videocam,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),

                                  // 选中/未选中遮罩
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: isSelected
                                          ? Colors.black.withOpacity(0.3)
                                          : Colors.black.withOpacity(0.6),
                                      border: isSelected
                                          ? Border.all(color: Colors.white, width: 2)
                                          : null,
                                    ),
                                  ),

                                  // 复选框
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.white : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected ? Colors.white : Colors.white54,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              color: Color(0xFF0A0A1A),
                                              size: 16,
                                            )
                                          : null,
                                    ),
                                  ),

                                  // 未选中时的文字提示
                                  if (!isSelected)
                                    const Center(
                                      child: Text(
                                        '未选中',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // 底部按钮
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // 取消按钮 - 毛玻璃风格
                      Expanded(
                        child: GestureDetector(
                          onTap: _onCancel,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                '取消',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 确认删除按钮 - 红色
                      Expanded(
                        child: GestureDetector(
                          onTap: _onConfirmDelete,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: selectedCount > 0 
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFEF4444).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Center(
                              child: Text(
                                selectedCount > 0 ? '确认删除 ($selectedCount)' : '确认删除',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 显示删除确认弹层的辅助函数
void showDeleteConfirmationSheet(BuildContext context, List<MediaItem> itemsToDelete) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DeleteConfirmationSheet(
      itemsToDelete: itemsToDelete,
    ),
  );
}
