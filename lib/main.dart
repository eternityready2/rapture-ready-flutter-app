import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:io';

// Local Libraries
import 'utils/WebView.dart';
import 'utils/AppLayoutCache.dart';
import 'utils/Color.dart';
import 'utils/AppImage.dart';
import 'utils/LayoutLoaders.dart';

// Services
import 'services/NotificationService.dart';
import 'services/CacheService.dart';

// Global
import 'global/Constants.dart';
import 'global/GlobalControllers.dart';
import 'global/AppState.dart';

import 'tabs/HomeScreen.dart';
import 'tabs/MoreScreen.dart';

import 'firebase_options.dart';


void main() async {

  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  final DateTime splashStartTime = DateTime.now();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.instance.initialize();

  await CacheService.initialize();

  runApp(AppStateWidget(
    appLayout: {},
    loaded: null,
    child: MyApp(splashStartTime: splashStartTime),
  ));
}

class MyApp extends StatefulWidget {
  final DateTime splashStartTime;
  const MyApp({Key? key, required this.splashStartTime}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Future<void> _initAsync() async {
    
    Map<String, dynamic> localLayout;
    String loaded;

    try {
      localLayout = await loadAppLayoutFromCache();
      loaded = "cache";
    } catch (e) {
      localLayout = await loadAppLayoutFromAssets();
      loaded = "assets";
    }

    final DateTime splashEndTime = DateTime.now();
    final elapsed = splashEndTime.difference(
      this.widget.splashStartTime
    ).inSeconds;

    final int timeToWait = 2;

    print("Loading Layout took: ${elapsed} seconds");
    AppStateWidget.of(context).setAppState(localLayout, loaded);
    loadNetworkAndUpdate(localLayout);

    if (elapsed >= timeToWait) {
      FlutterNativeSplash.remove();
    } else {
      await Future.delayed(Duration(seconds: timeToWait - elapsed), () async {
        FlutterNativeSplash.remove();
      });
    }
  }

  Future<void> loadNetworkAndUpdate(Map<String, dynamic> localLayout) async {
    final networkLayout = await loadAppLayoutFromNetwork();
    final firstTab = localLayout['tabs'][0];
    for (int idx = 0; idx < networkLayout['data']['sections'].length; idx++) {
      networkLayout['data']['sections'][idx] = {
        ...networkLayout['data']['sections'][idx],
        "underlineColor": "#0066ff",
      };
    }

    firstTab['sections'] = networkLayout['data']['sections'];

    localLayout['tabs'] = [
      for (var tab in localLayout['tabs'])
        if (
          tab['text']!.toLowerCase() == "home" ||
          tab['text']!.toLowerCase() == "more"
          ) tab
    ];

    var insertAt = 0;
    for (int idx = 0; idx < networkLayout['data']['bottomNav'].length; idx++) {
      var networkTab = networkLayout['data']['bottomNav'][idx]!;
      if (networkTab['text'].toLowerCase() == "home") {
        continue;
      }

      localLayout['tabs'].insert(insertAt + 1, {
        ...networkTab,
        'color': "#0066ff",
      });
      insertAt += 1;
    }

    final moreSections = [
      for (var section in localLayout['tabs'].last['sections'])
        if (section['link'].startsWith('ACTION'))
          section
    ];

    localLayout['tabs'].last['sections'] = [
      ...networkLayout['data']['more'], ...moreSections
    ];

    AppStateWidget.of(context).setAppState(localLayout, "network");
    await AppLayoutCache().writeJsonToCache(localLayout);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CacheService.clearAllCache();
    CacheService.stopBackgroundService();
    _initAsync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      CacheService.stopBackgroundService();
    }

    else if (state == AppLifecycleState.paused ||
      state == AppLifecycleState.detached) {
      CacheService.runBackgroundService();
    }
  }

  Future<void> _showAppReview() async {
    final directory = await getApplicationDocumentsDirectory();
    File file = File('${directory.path}/appReviewTimestamp.txt');

    final currentDate = DateTime.now();
    if (! (await file.exists()) ) {
      print('appReviewTimeStamp does not exist creating it...');
      await file.writeAsString(currentDate.toString());
      return;
    }

    final oldDate = DateTime.parse(await file.readAsString());
    if (currentDate.difference(oldDate).inDays < 3) {
      print('Do not show inAppReview because difference is less than 3 days');
      return;
    }

    await file.writeAsString(currentDate.toString());
    print('Initializing inAppReview');
    final InAppReview inAppReview = InAppReview.instance;
    if (await inAppReview.isAvailable()) {
        inAppReview.requestReview();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = AppStateScope.of(context);
    if (appState.loaded == null) {
      return Center(child: CircularProgressIndicator());
    }
    _showAppReview();
    print(appState.loaded);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VertiZontal Media',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: HexColor.fromHex(
            appState.appLayout['globalTheme']['color']!
          )
        ),
      ),
      home: AppNavigation()
    );
  }
}

class AppNavigation extends StatefulWidget {
  const AppNavigation({super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  int currentPageIndex = 0;
  int _rebuildFlag = 0;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> appLayout = AppStateScope.of(context).appLayout;
    final String loaded = AppStateScope.of(context).loaded!;
    final ThemeData theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {

          return;
        }

        if (webViewControllers.isNotEmpty) {
          GlobalWebViewController globalWebViewController =
              webViewControllers.last;
          InAppWebViewController? controller =
              globalWebViewController.controller;
          void Function()? customLastGoBack =
              globalWebViewController.customLastGoBack;

          if (controller != null) {
            try {
              final shouldPop = await controller.canGoBack();
              if (shouldPop) {
                await controller.goBack();
                return;
              }

              if (customLastGoBack != null)
              {
                customLastGoBack.call();
                webViewControllers.removeLast();
                return;
              }
            } catch (e) {
              print(e);
            }
          }
        }

        await CacheService.runBackgroundService();
        await SystemNavigator.pop();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(appLayout['tabs'][currentPageIndex]['text']! as String),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),

      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            if (index == currentPageIndex) {
              _rebuildFlag++;
            } else {
              currentPageIndex = index;
              _rebuildFlag = 0;
            }
          });
        },        
        indicatorColor: HexColor.fromHex(
          appLayout['tabs'][currentPageIndex]['color']
        ),
        selectedIndex: currentPageIndex,
        destinations: <Widget>[
          for (var tab in appLayout?['tabs'])
            NavigationDestination(
              selectedIcon: AppImage(
                path: tab['icon']!,
                width: 24,
                height: 24,
              ),
              icon: AppImage(
                path: tab['icon']!,
                width: 24,
                height: 24,
              ),
              label: tab?['text'],
            ),
        ],
      ),
        body: (() {
          final String link = appLayout['tabs'][currentPageIndex]['link']!;
          if (link.startsWith('http')) {
            return WebView(
              key: ValueKey('$link-$_rebuildFlag'),
              url: link,
            );
          } else if (link == "#") {
            return HomeScreen(key: ValueKey('home-$_rebuildFlag'));
          } else if (link == "more") {
            return MoreScreen(key: ValueKey('more-$_rebuildFlag'));
          }
          return SizedBox();
        })(),
        )
    );
  }
}
