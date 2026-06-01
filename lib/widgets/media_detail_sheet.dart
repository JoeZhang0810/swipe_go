import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_item.dart';

/// 显示媒体详情弹层
void showMediaDetailSheet(BuildContext context, MediaItem item) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => MediaDetailSheet(item: item),
  );
}

class MediaDetailSheet extends StatefulWidget {
  final MediaItem item;

  const MediaDetailSheet({super.key, required this.item});

  @override
  State<MediaDetailSheet> createState() => _MediaDetailSheetState();
}

class _MediaDetailSheetState extends State<MediaDetailSheet> {
  Uint8List? _thumbnail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final data = await widget.item.entity.thumbnailDataWithSize(
      const ThumbnailSize(400, 200),
      quality: 80,
    );
    if (mounted) {
      setState(() {
        _thumbnail = data;
        _loading = false;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _createDateTimeStr() {
    final dt = widget.item.createDateTime;
    final months = [
      '', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'
    ];
    return '${dt.year}年${months[dt.month]}月${dt.day}日 '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFA16161A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖动指示器
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 缩略图
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: double.infinity,
                height: 120,
                child: _loading
                    ? Container(
                        color: Colors.grey[900],
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white54,
                          ),
                        ),
                      )
                    : _thumbnail != null
                        ? Image.memory(_thumbnail!, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey[900],
                            child: const Icon(Icons.image, color: Colors.white38),
                          ),
              ),
            ),
            const SizedBox(height: 16),

            // 详情行
            _buildDetailRow(Icons.calendar_today_outlined, '拍摄时间',
                _createDateTimeStr()),
            _buildDetailRow(Icons.phone_iphone_outlined, '拍摄设备',
                widget.item.entity.relativePath ?? '未知设备'),
            _buildDetailRow(Icons.insert_drive_file_outlined, '文件大小',
                _formatFileSize(widget.item.size)),
            _buildDetailRow(
                Icons.crop_original_outlined, '分辨率',
                '${widget.item.width} × ${widget.item.height}'),

            // 拍摄位置（如果有）
            if (widget.item.latitude != null && widget.item.longitude != null) ...[
              _buildDetailRow(Icons.location_on_outlined, '拍摄位置', ''),
              _buildMapPreview(),
            ],

            const SizedBox(height: 12),

            // 收起按钮
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white54, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '收起',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white.withOpacity(0.4)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.45),
            ),
          ),
          const Spacer(),
          if (value.isNotEmpty)
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.85),
                ),
                textAlign: TextAlign.right,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapPreview() {
    return Container(
      width: double.infinity,
      height: 80,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2535), Color(0xFF2A3545)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 网格线
          CustomPaint(
            size: Size.infinite,
            painter: _GridPainter(),
          ),
          // 地图定位点
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF30A060),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
          // 位置文本
          Positioned(
            bottom: 6,
            right: 8,
            child: Text(
              '${widget.item.latitude ?? ''}, ${widget.item.longitude ?? ''}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x266496FF)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
