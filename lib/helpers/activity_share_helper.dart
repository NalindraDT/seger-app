import 'dart:io';
import 'dart:ui' as ui;

import 'package:appinio_social_share/appinio_social_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pltuapp/models/activity_share_data.dart';
import 'package:pltuapp/widgets/activity_share_card.dart';
import 'package:share_plus/share_plus.dart';

enum ActivitySharePlatform {
  whatsapp,
  instagram,
  facebook,
  telegram,
  twitter,
  copyText,
  other,
}

class ActivityShareHelper {
  static const Color primaryPurple = Color(0xFF5D44F8);

  static Future<void> showShareSheet(
    BuildContext context,
    ActivityShareData data,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ActivityShareSheet(data: data),
    );
  }

  static Future<File?> _captureShareCard(
    BuildContext context,
    ActivityShareData data,
  ) async {
    final key = GlobalKey();
    OverlayEntry? entry;

    entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        left: -2000,
        top: -2000,
        child: Material(
          color: Colors.transparent,
          child: RepaintBoundary(
            key: key,
            child: ActivityShareCard(data: data),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(entry);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/seger_activity_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file;
    } finally {
      entry.remove();
    }
  }

  static Future<void> shareToPlatform(
    BuildContext context,
    ActivityShareData data,
    ActivitySharePlatform platform,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final file = await _captureShareCard(context, data);
    final caption = data.shareCaption;
    final social = AppinioSocialShare();

    try {
      switch (platform) {
        case ActivitySharePlatform.whatsapp:
          if (Platform.isAndroid) {
            await social.android.shareToWhatsapp(caption, file?.path);
          } else if (Platform.isIOS && file != null) {
            await social.iOS.shareImageToWhatsApp(file.path);
          } else {
            await _shareFallback(file, caption);
          }
          break;

        case ActivitySharePlatform.instagram:
          if (file == null) {
            _showMessage(messenger, 'Gagal membuat gambar bagikan.', isError: true);
            return;
          }
          if (Platform.isAndroid) {
            await social.android.shareToInstagramFeed(caption, file.path);
          } else if (Platform.isIOS) {
            await social.iOS.shareToInstagramFeed(file.path);
          } else {
            await _shareFallback(file, caption);
          }
          break;

        case ActivitySharePlatform.facebook:
          if (file == null) {
            _showMessage(messenger, 'Gagal membuat gambar bagikan.', isError: true);
            return;
          }
          if (Platform.isAndroid) {
            await social.android.shareToFacebook('#SEGER', [file.path]);
          } else if (Platform.isIOS) {
            await social.iOS.shareToFacebook('#SEGER', [file.path]);
          } else {
            await _shareFallback(file, caption);
          }
          break;

        case ActivitySharePlatform.telegram:
          if (Platform.isAndroid) {
            await social.android.shareToTelegram(caption, file?.path);
          } else if (Platform.isIOS) {
            await social.iOS.shareToTelegram(caption);
          } else {
            await _shareFallback(file, caption);
          }
          break;

        case ActivitySharePlatform.twitter:
          if (Platform.isAndroid) {
            await social.android.shareToTwitter(caption, file?.path);
          } else if (Platform.isIOS) {
            await social.iOS.shareToTwitter(caption, file?.path);
          } else {
            await _shareFallback(file, caption);
          }
          break;

        case ActivitySharePlatform.copyText:
          await Clipboard.setData(ClipboardData(text: caption));
          _showMessage(messenger, 'Teks aktivitas disalin ke clipboard.', isError: false);
          break;

        case ActivitySharePlatform.other:
          await _shareFallback(file, caption);
          break;
      }
    } catch (e) {
      await _shareFallback(file, caption);
    }
  }

  static Future<void> _shareFallback(File? file, String caption) async {
    if (file != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: caption,
          subject: 'Aktivitas SEGER',
        ),
      );
    } else {
      await SharePlus.instance.share(
        ShareParams(
          text: caption,
          subject: 'Aktivitas SEGER',
        ),
      );
    }
  }

  static void _showMessage(
    ScaffoldMessengerState messenger,
    String message, {
    required bool isError,
  }) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ActivityShareSheet extends StatefulWidget {
  final ActivityShareData data;

  const _ActivityShareSheet({required this.data});

  @override
  State<_ActivityShareSheet> createState() => _ActivityShareSheetState();
}

class _ActivityShareSheetState extends State<_ActivityShareSheet> {
  ActivitySharePlatform? _sharingPlatform;

  Future<void> _onPlatformTap(ActivitySharePlatform platform) async {
    if (_sharingPlatform != null) return;

    setState(() => _sharingPlatform = platform);

    await ActivityShareHelper.shareToPlatform(context, widget.data, platform);

    if (mounted) {
      setState(() => _sharingPlatform = null);
      if (platform != ActivitySharePlatform.copyText) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Bagikan Aktivitas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pilih platform untuk membagikan pencapaianmu',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          Center(
            child: Transform.scale(
              scale: 0.72,
              child: ActivityShareCard(data: widget.data),
            ),
          ),
          const SizedBox(height: 20),
          if (_sharingPlatform != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ActivityShareHelper.primaryPurple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Menyiapkan konten...', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
            children: [
              _buildPlatformButton(
                platform: ActivitySharePlatform.whatsapp,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                icon: Icons.chat,
              ),
              _buildPlatformButton(
                platform: ActivitySharePlatform.instagram,
                label: 'Instagram',
                gradient: const [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
                icon: Icons.camera_alt,
              ),
              _buildPlatformButton(
                platform: ActivitySharePlatform.facebook,
                label: 'Facebook',
                color: const Color(0xFF1877F2),
                icon: Icons.facebook,
              ),
              _buildPlatformButton(
                platform: ActivitySharePlatform.telegram,
                label: 'Telegram',
                color: const Color(0xFF0088CC),
                icon: Icons.send,
              ),
              _buildPlatformButton(
                platform: ActivitySharePlatform.twitter,
                label: 'X',
                color: const Color(0xFF000000),
                icon: Icons.alternate_email,
              ),
              _buildPlatformButton(
                platform: ActivitySharePlatform.copyText,
                label: 'Salin',
                color: ActivityShareHelper.primaryPurple,
                icon: Icons.copy,
              ),
              _buildPlatformButton(
                platform: ActivitySharePlatform.other,
                label: 'Lainnya',
                color: Colors.grey.shade700,
                icon: Icons.share,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformButton({
    required ActivitySharePlatform platform,
    required String label,
    required IconData icon,
    Color? color,
    List<Color>? gradient,
  }) {
    final isLoading = _sharingPlatform == platform;
    final isDisabled = _sharingPlatform != null && !isLoading;

    return Opacity(
      opacity: isDisabled ? 0.45 : 1,
      child: InkWell(
        onTap: isDisabled ? null : () => _onPlatformTap(platform),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: gradient == null ? color : null,
                gradient: gradient != null
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradient,
                      )
                    : null,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (color ?? gradient?.first ?? Colors.grey).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
