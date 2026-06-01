import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_item.dart';
import '../providers/app_providers.dart';
import '../screens/launch_screen.dart';

// 选中状态管理
final selectedItemsProvider =
    StateNotifierProvider<SelectedItemsNotifier, Set<String>>((ref) {
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
  ConsumerState<DeleteConfirmationSheet> createState() =>
      _DeleteConfirmationSheetState();
}

class _DeleteConfirmationSheetState
    extends ConsumerState<DeleteConfirmationSheet> {
  final Map<String, Uint8List?> _thumbnails = {};
  bool _isLoadingThumbnails = true;

  @override
  void initState() {
    super.initState();
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
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LaunchScreen()),
      (route) => false,
    );
  }

  Future<void> _onConfirmDelete() async {
    final selectedIds = ref.read(selectedItemsProvider);

    if (selectedIds.isEmpty) {
      _onCancel();
      return;
    }

    // 请求相册权限（会触发系统弹窗）
    final permission = await PhotoManager.requestPermissionExtend();

    if (!permission.isAuth) {
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

    // 执行删除
    try {
      await PhotoManager.editor.deleteWithIds(selectedIds.toList());

      final deletedCount = selectedIds.length;
      int totalSpace = 0;
      for (final item in widget.itemsToDelete) {
        if (selectedIds.contains(item.id)) {
          totalSpace += item.size;
        }
      }

      await ref
          .read(statsProvider.notifier)
          .addDeleted(deletedCount, totalSpace);

      ref.read(mediaListProvider.notifier).clear();
      ref.read(selectedItemsProvider.notifier).clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已成功删除 $deletedCount 个项目'),
            backgroundColor: Colors.green,
          ),
        );

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

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFA0F0F0F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 拖动指示器
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 16),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 标题
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        '回顾完毕',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '请确认需要删除的照片',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 照片网格
                Expanded(
                  child: widget.itemsToDelete.isEmpty
                      ? const Center(
                          child: Text(
                            '没有要删除的项目',
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        )
                      : GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: widget.itemsToDelete.length,
                          itemBuilder: (context, index) {
                            final item = widget.itemsToDelete[index];
                            final isSelected =
                                ref.watch(selectedItemsProvider.notifier).isSelected(item.id);
                            final thumbData = _thumbnails[item.id];

                            return GestureDetector(
                              onTap: () {
                                ref
                                    .read(selectedItemsProvider.notifier)
                                    .toggle(item.id);
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // 缩略图
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: thumbData != null
                                        ? Image.memory(
                                            thumbData,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            color: const Color(0xFF1A1A1A),
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white54),
                                              ),
                                            ),
                                          ),
                                  ),

                                  // 选中边框
                                  if (isSelected)
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0x8030D158),
                                          width: 2,
                                        ),
                                      ),
                                    ),

                                  // 绿色对勾徽章
                                  Positioned(
                                    bottom: -4,
                                    right: -4,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF30D158)
                                            : Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(11),
                                        border: Border.all(
                                          color: const Color(0xFF0F0F0F),
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 12,
                                            )
                                          : null,
                                    ),
                                  ),

                                  // 视频标识
                                  if (item.isVideo)
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Icon(
                                          Icons.videocam,
                                          color: Colors.white,
                                          size: 14,
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 38),
                  child: Column(
                    children: [
                      // 红色删除按钮
                      GestureDetector(
                        onTap: selectedCount > 0 ? _onConfirmDelete : null,
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            color: selectedCount > 0
                                ? const Color(0xD9C83232)
                                : const Color(0x44C83232),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: Center(
                            child: Text(
                              '删除 $selectedCount 张照片',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 放弃按钮
                      GestureDetector(
                        onTap: _onCancel,
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '放弃，再来一组',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
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
        );
      },
    );
  }
}

// 显示删除确认弹层
void showDeleteConfirmationSheet(
    BuildContext context, List<MediaItem> itemsToDelete) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DeleteConfirmationSheet(
      itemsToDelete: itemsToDelete,
    ),
  );
}
