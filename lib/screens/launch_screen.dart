import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../widgets/stats_settings_sheet.dart';
import 'browse_screen.dart';

class LaunchScreen extends ConsumerStatefulWidget {
  const LaunchScreen({super.key});

  @override
  ConsumerState<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends ConsumerState<LaunchScreen> {
  List<AssetEntity> _selectedPhotos = [];
  List<Uint8List?> _photoThumbs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRandomPhotos();
  }

  Future<void> _loadRandomPhotos() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      setState(() { _isLoading = false; });
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );

    if (albums.isEmpty) {
      setState(() { _isLoading = false; });
      return;
    }

    final allPhotos = await albums.first.getAssetListPaged(page: 0, size: 100);

    if (allPhotos.length < 3) {
      setState(() { _isLoading = false; });
      return;
    }

    final random = Random();
    final selectedIndices = <int>{};
    while (selectedIndices.length < 3) {
      selectedIndices.add(random.nextInt(allPhotos.length));
    }

    _selectedPhotos = selectedIndices.map((i) => allPhotos[i]).toList();

    final thumbs = await Future.wait(
      _selectedPhotos.map((photo) => photo.thumbnailDataWithSize(
        const ThumbnailSize(800, 800),
        quality: 80,
      )),
    );

    setState(() {
      _photoThumbs = thumbs;
      _isLoading = false;
    });
  }

  void _openStatsSettings() {
    StatsSettingsSheet.show(context);
  }

  void _navigateToBrowse() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const BrowseScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF111111),
        child: Stack(
          children: [
            // 照片叠放区域
            SizedBox.expand(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white))
                  : _photoThumbs.isEmpty
                      ? const Center(
                          child: Text('暂无照片',
                              style: TextStyle(color: Colors.white, fontSize: 16)))
                      : _buildStackedPhotos(),
            ),

            // 右上角设置按钮 - 毛玻璃圆形 36x36, gear icon
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 20,
              child: GestureDetector(
                onTap: _openStatsSettings,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.settings_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 底部"开始"按钮 - 半透明暗色底 + 白色文字
            Positioned(
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).padding.bottom + 40,
              child: GestureDetector(
                onTap: _navigateToBrowse,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '开始',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStackedPhotos() {
    // 三张照片叠放，匹配 HTML: card1(-8°), card2(+4°), card3(-2°)
    final rotations = [-0.14, 0.07, -0.035];

    return Center(
      child: SizedBox(
        width: 220,
        height: 330,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (int i = 0; i < 3 && i < _photoThumbs.length; i++)
              Positioned(
                child: Transform.translate(
                  offset: i == 0
                      ? const Offset(-10, 30)
                      : i == 1
                          ? const Offset(25, 15)
                          : const Offset(5, 0),
                  child: Transform.rotate(
                    angle: rotations[i],
                    child: Container(
                      width: i == 0 ? 190.0 : i == 1 ? 195.0 : 185.0,
                      height: i == 0 ? 255.0 : i == 1 ? 265.0 : 250.0,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _photoThumbs[i] != null
                            ? Image.memory(
                                _photoThumbs[i]!,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey[850],
                                child: const Icon(
                                  Icons.image,
                                  color: Colors.white38,
                                  size: 40,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
