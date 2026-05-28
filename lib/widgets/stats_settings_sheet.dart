import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_providers.dart';

class StatsSettingsSheet extends ConsumerWidget {
  const StatsSettingsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const StatsSettingsSheet(),
    );
  }

  Future<void> _sendFeedbackEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'zqloop@icloud.com',
      queryParameters: {
        'subject': 'SwipeGo 产品建议',
        'body': '您好，我有以下建议：\n\n',
      },
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final settings = ref.watch(settingsProvider);

    return ClipRRect(
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
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 拖动指示器
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 统计模块
                  _buildSectionTitle('统计'),
                  const SizedBox(height: 12),
                  _buildStatsCard(stats.totalViewed, stats.totalDeleted, stats.spaceSavedFormatted),
                  const SizedBox(height: 24),

                  // 设置模块
                  _buildSectionTitle('设置'),
                  const SizedBox(height: 12),
                  _buildSettingsCard(context, ref, settings),
                  const SizedBox(height: 24),

                  // 建议模块
                  _buildSectionTitle('建议'),
                  const SizedBox(height: 12),
                  _buildFeedbackCard(context),
                  const SizedBox(height: 32),

                  // 底部产品信息
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  Widget _buildStatsCard(int viewed, int deleted, String spaceSaved) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem('已查看', viewed.toString(), Icons.visibility_outlined),
          ),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.15)),
          Expanded(
            child: _buildStatItem('已删除', deleted.toString(), Icons.delete_outline),
          ),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.15)),
          Expanded(
            child: _buildStatItem('已释放', spaceSaved, Icons.storage_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.white.withOpacity(0.8)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(BuildContext context, WidgetRef ref, dynamic settings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 每组数量设置
          Text(
            '每组数量',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [15, 30, 50].map((size) {
              final isSelected = settings.batchSize == size;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      ref.read(settingsProvider.notifier).updateSettings(batchSize: size);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xF2FFFFFF), // 0.95 opacity
                                  Color(0x66FFFFFF), // 0.4 opacity
                                ],
                              )
                            : null,
                        color: isSelected ? null : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white.withOpacity(0.3)
                              : Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        '$size',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF0A0A1A)
                              : Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),

          // 内容类型设置
          Text(
            '内容类型',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildContentTypeCheckbox(
                  label: '照片',
                  value: settings.showPhotos,
                  onChanged: (value) {
                    // 确保至少选中一种
                    if (!value! && !settings.showVideos) {
                      _showMustSelectOneTip(context);
                      return;
                    }
                    ref.read(settingsProvider.notifier).updateSettings(showPhotos: value);
                  },
                ),
              ),
              Expanded(
                child: _buildContentTypeCheckbox(
                  label: '视频',
                  value: settings.showVideos,
                  onChanged: (value) {
                    // 确保至少选中一种
                    if (!value! && !settings.showPhotos) {
                      _showMustSelectOneTip(context);
                      return;
                    }
                    ref.read(settingsProvider.notifier).updateSettings(showVideos: value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentTypeCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: value ? Colors.white : Colors.transparent,
              border: Border.all(
                color: value ? Colors.white : Colors.white.withOpacity(0.5),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: value
                ? const Icon(
                    Icons.check,
                    color: Color(0xFF0A0A1A),
                    size: 16,
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  void _showMustSelectOneTip(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('请至少选择一种内容类型'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildFeedbackCard(BuildContext context) {
    return GestureDetector(
      onTap: _sendFeedbackEmail,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              color: Colors.amber.shade400,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '有产品建议？',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '点击这里发送邮件给开发者',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.white.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          const Text(
            '划咯 SwipeGo',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'v1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
