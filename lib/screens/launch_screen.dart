import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../providers/app_providers.dart';
import 'browse_screen.dart';
import '../widgets/stats_settings_sheet.dart';

class LaunchScreen extends ConsumerStatefulWidget {
  const LaunchScreen({super.key});

  @override
  ConsumerState<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends ConsumerState<LaunchScreen> {
  List<AssetEntity> _selectedPhotos = [];
  List<Uint8List?> _photoThumbs = [];
  bool _isLoading = true;
  bool _showStatsSettings = false;

  @override
  void initState() {
    super.initState();
    _loadRandomPhotos();
  }

  Future<void> _loadRandomPhotos() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );

    if (albums.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final allPhotos = await albums.first.getAssetListPaged(
      page: 0,
      size: 100,
    );

    if (allPhotos.length < 3) {
      setState(() {
        _isLoading = false;
      });
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

  void _toggleStatsSettings() {
    setState(() {
      _showStatsSettings = !_showStatsSettings;
    });
  }

  void _navigateToBrowse() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BrowseScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Stack(
        children: [
          // 照片叠放区域 - 占屏幕约4/5
          SizedBox.expand(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  )
                : _photoThumbs.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无照片',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : _buildStackedPhotos(),
          ),

          // 右上角毛玻璃统计设置按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: GestureDetector(
              onTap: _toggleStatsSettings,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    child: Icon(
                      _showStatsSettings ? Icons.close : Icons.bar_chart,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 统计设置弹层
          if (_showStatsSettings)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              right: 16,
              left: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    child: const StatsSettingsSheet(),
                  ),
                ),
              ),
            ),

          // 底部白色渐变开始按钮
          Positioned(
            left: 32,
            right: 32,
            bottom: MediaQuery.of(context).padding.bottom + 32,
            child: GestureDetector(
              onTap: _navigateToBrowse,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xF2FFFFFF), // 0.95 opacity
                      Color(0x66FFFFFF), // 0.4 opacity
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '开始',
                    style: TextStyle(
                      color: Color(0xFF0A0A1A),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStackedPhotos() {
    // 定义三张图片的偏移和旋转，实现叠放不对齐效果
    final offsets = [
      const Offset(-20, -30),
      const Offset(15, 10),
      const Offset(-10, 40),
    ];

    final rotations = [
      -0.08,
      0.05,
      -0.03,
    ];

    final scales = [0.95, 1.0, 0.92];

    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7, // 调整高度使照片区域占约4/5
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (int i = 0; i < _photoThumbs.length; i++)
              Positioned(
                child: Transform.translate(
                  offset: offsets[i],
                  child: Transform.rotate(
                    angle: rotations[i],
                    child: Transform.scale(
                      scale: scales[i],
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.75,
                        height: MediaQuery.of(context).size.height * 0.55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _photoThumbs[i] != null
                              ? Image.memory(
                                  _photoThumbs[i]!,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.image,
                                    color: Colors.white54,
                                    size: 48,
                                  ),
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
