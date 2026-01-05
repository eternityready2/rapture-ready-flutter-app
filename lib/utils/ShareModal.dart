import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import './Color.dart';

Future<void> showShareModal(
  BuildContext context, {
  required String urlToShare,
}) async {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            width: MediaQuery.of(ctx).size.width * 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Share',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Platforms row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SharePlatformButton(
                      label: 'WhatsApp',
                      imagePath: 'assets/images/WhatsApp.png',
                      onTap: () => _shareWhatsApp(urlToShare),
                      backgroundColor: HexColor.fromHex('#41c452')
                    ),
                    _SharePlatformButton(
                      label: 'SMS',
                      imagePath: 'assets/images/Sms.png',
                      onTap: () => _shareSMS(urlToShare),
                      backgroundColor: HexColor.fromHex('#ffffff')
                    ),
                    _SharePlatformButton(
                      label: 'Email',
                      imagePath: 'assets/images/Email.png',
                      onTap: () => _shareEmail(urlToShare),
                      backgroundColor: HexColor.fromHex('#ffffff')
                    ),
                    _SharePlatformButton(
                      label: 'Facebook',
                      imagePath: 'assets/images/Facebook.png',
                      onTap: () => _shareFacebook(urlToShare),
                      backgroundColor: HexColor.fromHex('#0866ff')
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _CopyLinkField(urlToShare: urlToShare),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SharePlatformButton extends StatelessWidget {
  final String label;
  final String imagePath;
  final VoidCallback onTap;
  final Color? backgroundColor;
  const _SharePlatformButton({
    super.key,
    required this.label,
    required this.imagePath,
    required this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                imagePath,
                width: 56 * 0.65,
                height: 56 * 0.65,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ================== SHARE HANDLERS ==================


Future<void> _shareWhatsApp(String articleLink) async {
  final message = '''
Rapture Ready App

Article Link: $articleLink

Download our App at the following Platforms:
iOS: https://apps.apple.com/us/app/rapture-ready-eternity-ready/id6504677632
Android: https://play.google.com/store/apps/details?id=com.wRaptureReadyEndTimesNewsProphecyDoctrineofPreTribRapture&hl=en-US
''';
  
  final encoded = Uri.encodeComponent(message);
  final uri = Uri.parse('https://wa.me/?text=$encoded');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> _shareSMS(String articleLink) async {
  final message = '''
Rapture Ready App

Article Link: $articleLink

Download our App at the following Platforms:
iOS: https://apps.apple.com/us/app/rapture-ready-eternity-ready/id6504677632
Android: https://play.google.com/store/apps/details?id=com.wRaptureReadyEndTimesNewsProphecyDoctrineofPreTribRapture&hl=en-US
''';
  
  final encoded = Uri.encodeComponent(message);
  final uri = Uri.parse('sms:?body=$encoded');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

Future<void> _shareEmail(String articleLink) async {
  final message = '''
Rapture Ready App

Article Link: $articleLink

Download our App at the following Platforms:
iOS: https://apps.apple.com/us/app/rapture-ready-eternity-ready/id6504677632
Android: https://play.google.com/store/apps/details?id=com.wRaptureReadyEndTimesNewsProphecyDoctrineofPreTribRapture&hl=en-US
''';
  
  final subject = Uri.encodeComponent('Rapture Ready App');
  final body = Uri.encodeComponent(message);
  final uri = Uri.parse('mailto:?subject=$subject&body=$body');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

Future<void> _shareFacebook(String articleLink) async {
  final message = '''
Rapture Ready App

Article Link: $articleLink

Download our App at the following Platforms:
iOS: https://apps.apple.com/us/app/rapture-ready-eternity-ready/id6504677632
Android: https://play.google.com/store/apps/details?id=com.wRaptureReadyEndTimesNewsProphecyDoctrineofPreTribRapture&hl=en-US
''';
  
  final encoded = Uri.encodeComponent(message);
  final uri = Uri.parse('https://www.facebook.com/sharer/sharer.php?u=$encoded');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _CopyLinkField extends StatelessWidget {
  final String urlToShare;

  const _CopyLinkField({
    super.key,
    required this.urlToShare,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          // Expanded text field
          Expanded(
            child: TextField(
              controller: TextEditingController(text: urlToShare),
              readOnly: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Copy button
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: urlToShare),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied')),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
