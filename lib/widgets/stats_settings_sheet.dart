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

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF71C1C20),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
          child: Column(
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

              // 统计模块
              _buildSectionTitle('统计'),
              const SizedBox(height: 12),
              _buildStatsRow(stats.totalViewed, stats.totalDeleted,
                  stats.spaceSavedFormatted),
              const SizedBox(height: 24),

              // 设置模块
              _buildSectionTitle('设置'),
              const SizedBox(height: 12),
              _buildSettingsBlock(context, ref, settings),
              const SizedBox(height: 24),

              // 建议模块
              _buildSectionTitle('建议'),
              const SizedBox(height: 12),
              _buildFeedbackRow(context),
              const SizedBox(height: 28),

              // 底部
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Colors.white.withOpacity(0.4),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildStatsRow(int viewed, int deleted, String spaceSaved) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('$viewed', '已查看')),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard('$deleted', '已删除')),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard(spaceSaved, '已释放')),
      ],
    );
  }

  Widget _buildStatCard(String number, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsBlock(
      BuildContext context, WidgetRef ref, dynamic settings) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // 每组数量
          _buildSettingsRow(
            label: '每组数量',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [15, 30, 50].map((size) {
                final isSelected = settings.batchSize == size;
                return GestureDetector(
                  onTap: () {
                    ref
                        .read(settingsProvider.notifier)
                        .updateSettings(batchSize: size);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.18)
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$size',
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // 分隔线
          Divider(
            height: 1,
            color: Colors.white.withOpacity(0.07),
          ),

          // 内容类型
          _buildSettingsRow(
            label: '内容类型',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypeChip(
                  label: '照片',
                  selected: settings.showPhotos,
                  onTap: () {
                    if (!settings.showPhotos && !settings.showVideos) {
                      _showMustSelectOneTip(context);
                      return;
                    }
                    ref
                        .read(settingsProvider.notifier)
                        .updateSettings(showPhotos: !settings.showPhotos);
                  },
                ),
                const SizedBox(width: 6),
                _buildTypeChip(
                  label: '视频',
                  selected: settings.showVideos,
                  onTap: () {
                    if (!settings.showVideos && !settings.showPhotos) {
                      _showMustSelectOneTip(context);
                      return;
                    }
                    ref
                        .read(settingsProvider.notifier)
                        .updateSettings(showVideos: !settings.showVideos);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsRow({
    required String label,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0x2630D158)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(
                  color: const Color(0x4D30D158),
                  width: 0.5,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: Color(0xFF30D158),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check,
                    size: 10, color: Colors.white),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: selected
                    ? const Color(0xFF30D158)
                    : Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
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

  Widget _buildFeedbackRow(BuildContext context) {
    return GestureDetector(
      onTap: _sendFeedbackEmail,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '有想法或问题？欢迎发邮件给开发者反馈建议',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.mail_outline,
                  size: 16, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Container(
          height: 1,
          color: Colors.white.withOpacity(0.07),
        ),
        const SizedBox(height: 20),
        Text(
          '划咯 · SwipeGo',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'v 1.0.0',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.25),
          ),
        ),
      ],
    );
  }
}
