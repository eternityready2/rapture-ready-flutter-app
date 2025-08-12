import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

// Local Libraries
import '../utils/WebView.dart';
import '../utils/AppLayoutCache.dart';
import '../utils/Color.dart';
import '../utils/AppImage.dart';

// Services
import '../services/CacheService.dart';

import '../global/AppState.dart';

class MoreScreen extends StatefulWidget {
  final void Function(dynamic)? onWebViewCreated;
  const MoreScreen({super.key, this.onWebViewCreated});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  String? _url;

  void _handleLinkClicked(String? linkUrl, String? android, String? ios, BuildContext context) async {
    if (linkUrl == null) {
      return;
    }

    if (linkUrl == "ACTION_SEND") {
      await SharePlus.instance.share(
        ShareParams(text: Platform.isAndroid ? android : ios)
      );
      return;
    }

    if (linkUrl == "ACTION_VIEW") {
      await launchUrl(
        Uri.parse((Platform.isAndroid ? android : ios) ?? "https://eternityready.com"),
        mode: LaunchMode.externalApplication
      );
      return;
    }

    if (linkUrl == "ACTION_THEME") {
      final selectedColor = await showColorPickerDialog(context);
      if (selectedColor == null) {
        return;
      }

      final AppState appState = AppStateScope.of(context);
      final Map<String, dynamic> appLayout = {
        ...appState.appLayout,
        "globalTheme": {
          ...appState.appLayout['globalTheme']!,
          'color': selectedColor
        }
      };

      await AppLayoutCache().writeJsonToCache(appLayout);
      AppStateWidget.of(context).setAppState(appLayout, appState.loaded!);
      return;
    }

    if (linkUrl == "ACTION_ABOUT") {

      await showAboutDialog(context);
      return;
    }

    if (linkUrl == "ACTION_EXIT") {
      await CacheService.runBackgroundService();
      FlutterExitApp.exitApp();
      return;
    }

    if (!linkUrl.startsWith("http")) {
      return;
    }

    setState(() {
      _url = linkUrl;
    });
  }

  void customLastGoBack() {
    setState(() {
      _url = null;
    });
  }

  Future<String?> showColorPickerDialog(BuildContext context) async {
    final colors = <String> [
        "FF263238",
        "FF212121",
        "FF3E2723",
        "FFBF360C",
        "FFE65100",
        "FFFF6D00",
        "FF33691E",
        "FF1B5E20",
        "FF004D40",
        "FF006064",
        "FF01579B",
        "FF0D47A1",
        "FF2962FF",
        "FF1A237E",
        "FF311B92",
        "FF880E4F",
        "FFB71C1C",
    ];

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose a color'),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in colors)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(color),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: HexColor.fromHex(color),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> showAboutDialog(BuildContext context) async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Center(child: Text(packageInfo.appName)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Version ${packageInfo.version}',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Image.asset(
              'assets/icon/splash.png',
              width: 128,
              height: 128,
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                launchUrl(
                  Uri.parse("https://eternityready.com"),
                  mode: LaunchMode.externalApplication
                );
              },
              child: Text(
                'Visit our website',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Powered by Eternity Ready Media',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'Cancel'),
            child: const Text('Cancel'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> appLayout = AppStateScope.of(context).appLayout;
    var moreTab;

    for (var tab in appLayout['tabs']!) {
      if (tab['text']!.toLowerCase() == "more") {
        moreTab = tab;
      }
    }
    if (moreTab == null) {
      return Center(
        child: Text("No 'More' Tab was found on tabs")
      );
    }

    if (_url != null) {
      return WebView(
        url: _url!,
        customLastGoBack: customLastGoBack,
        key: ValueKey(_url),
        onWebViewCreated: this.widget.onWebViewCreated,
      );
    }
    return ListView(
      children: <Widget>[
        for (var section in moreTab['sections'])
          Card(
            child: GestureDetector(
              onTap: () {
                _handleLinkClicked(
                  section?['link'],
                  section?['android'],
                  section?['ios'],
                  context,
                );
              },
              child: ListTile(
                leading: AppImage(
                  path: section['icon']!,
                  width: 24,
                  height: 24,
                  color: HexColor.fromHex(section['color'] ?? "#0066ff"),
                ),
                title: Text(section['text']!),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ),
      ],
    );
  }
}
