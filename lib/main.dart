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

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

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

  await initGoogleCast();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.instance.initialize();

  await CacheService.initialize();


  HttpClient.enableTimelineLogging = true;

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
  bool _showSecondSplashScreen = true;
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

    final int timeToWait = 1;

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
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _hideSplashAndShowReview();
      }
    });
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

  void _hideSplashAndShowReview() {
    setState(() => _showSecondSplashScreen = false);

    _showAppReview();
  }

  
  @override
  Widget build(BuildContext context) {
    final AppState appState = AppStateScope.of(context);

    if (appState.loaded == null) {
      return SecondSplashScreen();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rapture Ready',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: HexColor.fromHex(
            appState.appLayout['globalTheme']['color']!
          ),
        ),
      ),
      home: Stack(
        children: [
          AppNavigation(),
          if (_showSecondSplashScreen)
            Positioned.fill(child: SecondSplashScreen()),
        ]
      )
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
  InAppWebViewController? _webViewController;
  TransformationController _interactiveViewerController = TransformationController();

  List<Widget?> _tabWidgets = [];
  List<String?> _tabUrls = [];
  List<InAppWebViewController?> _webViewControllers = [];

  @override
  void dispose() {
    _interactiveViewerController.dispose();
    super.dispose();
  }

  void _zoomInInteractiveViewer() {
    final matrix = _interactiveViewerController.value;
    final zoom = matrix.getMaxScaleOnAxis();
    if (zoom < 4.0) { // max zoom limit
      _interactiveViewerController.value = matrix.scaled(1.2);
    }
  }

  void _zoomOutInteractiveViewer() {
    final matrix = _interactiveViewerController.value;
    final currentScale = matrix.getMaxScaleOnAxis();
    final minScale = 1.0; // initial/reset scale
    final zoomFactor = 1 / 1.2; // zoom out factor

    if (currentScale <= minScale) {
      // Already at or below the min scale, reset exactly to identity matrix
      _interactiveViewerController.value = Matrix4.identity();
    } else {
      final newScale = currentScale * zoomFactor;
      if (newScale < minScale) {
        _interactiveViewerController.value = Matrix4.identity();
      } else {
        _interactiveViewerController.value = matrix.scaled(zoomFactor);
      }
    }
  }

  void _resetZoomInteractiveViewer() {
    _interactiveViewerController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = AppStateScope.of(context).appLayout['tabs'] as List<dynamic>;
    final theme = Theme.of(context);

    // Initialize or extend the lists to match the number of tabs
    while (_tabWidgets.length < tabs.length) _tabWidgets.add(null);
    while (_tabUrls.length < tabs.length) _tabUrls.add(null);
    while (_webViewControllers.length < tabs.length) _webViewControllers.add(null);
    print(_tabWidgets);
    print(_tabUrls);
    print(_webViewControllers);


    for (int i = 0; i < tabs.length; i++) {
      final tab = tabs[i];
      final link = tab['link'] as String;

      final cachedUrl = _tabUrls[i];

      // Only recreate the widget if the URL changed or widget is null
      if (_tabWidgets[i] == null || cachedUrl != link) {
        _tabUrls[i] = link;

        if (link.startsWith('http')) {
          _tabWidgets[i] = WebView(
            key: ValueKey('webview-$i-$link'),
            url: link,
            onWebViewCreated: (controller) {
              _webViewControllers[i] = controller;
              setState(() {}); // update when controller assigned
            },
          );
        } else if (link == "#") {
          _tabWidgets[i] = InteractiveViewer(
            transformationController: _interactiveViewerController,
            panEnabled: true,
            scaleEnabled: true,
            child: HomeScreen(
              key: ValueKey('home-$i-$link'),
              onWebViewCreated: (controller) {
                _webViewControllers[i] = controller;
                setState(() {});
              },
            ),
          );
        } else if (link.toLowerCase() == "more") {
          _tabWidgets[i] = InteractiveViewer(
            transformationController: _interactiveViewerController,
            panEnabled: true,
            scaleEnabled: true,
            child: MoreScreen(
              key: ValueKey('more-$i-$link'),
              onWebViewCreated: (controller) {
                _webViewControllers[i] = controller;
                setState(() {});
              },
            ),
          );
        } else {
          _tabWidgets[i] = SizedBox.shrink();
        }
      }
    }

    // Now use your PopScope and Scaffold, unchanged from your last working version:
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }

        if (webViewControllers.isNotEmpty) {
          GlobalWebViewController globalWebViewController = webViewControllers.last;
          InAppWebViewController? controller = globalWebViewController.controller;
          void Function()? customLastGoBack = globalWebViewController.customLastGoBack;

          if (controller != null) {
            try {
              final shouldPop = await controller.canGoBack();
              if (shouldPop) {
                await controller.goBack();
                return;
              }

              if (customLastGoBack != null) {
                customLastGoBack.call();
                webViewControllers.removeLast();
                setState(() {
                  _webViewControllers[currentPageIndex] = null; // update current controller
                });
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
          title: Text(tabs[currentPageIndex]['text']! as String),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          actions: [
            if (Platform.isAndroid)
              IconButton(
                tooltip: "Screen cast",
                icon: Icon(Icons.cast, semanticLabel: "Screen cast"),
                onPressed: () async {
                  try {
                    final intent = AndroidIntent(
                      action: 'android.settings.CAST_SETTINGS',
                      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
                    );
                    await intent.launch();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Device not supported"),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                }
              ),
            if (Platform.isIOS)
              IconButton(
                tooltip: "Screen cast",
                icon: Icon(Icons.cast, semanticLabel: "Screen cast"),
                onPressed: () {
                  _showCastDevicesDialog(context);
                },
              ),
            IconButton(
              tooltip: "Zoom Out",
              icon: Icon(Icons.zoom_out, semanticLabel: "Zoom out"),
              onPressed: () async {
                final currentController = _webViewControllers[currentPageIndex];
                if (currentController != null) {
                  bool zoomOut = await currentController.zoomOut();
                  print('ZoomOut $zoomOut');
                } else {
                  _zoomOutInteractiveViewer();
                }
              },
            ),
            IconButton(
              tooltip: "Reset Zoom",
              icon: Icon(Icons.zoom_out_map, semanticLabel: "Reset zoom"),
              onPressed: () async {
                final currentController = _webViewControllers[currentPageIndex];
                if (currentController != null) {
                  while (await currentController!.zoomOut()) {}
                } else {
                  _resetZoomInteractiveViewer();
                }
              },
            ),
            IconButton(
              tooltip: "Zoom In",
              icon: Icon(Icons.zoom_in, semanticLabel: "Zoom in"),
              onPressed: () async {
                final currentController = _webViewControllers[currentPageIndex];
                if (currentController != null) {
                  bool zoomIn = await currentController.zoomIn();
                  print('ZoomIn $zoomIn');
                } else {
                  _zoomInInteractiveViewer();
                }
              },
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          onDestinationSelected: (int index) async {
            final tabs = AppStateScope.of(context).appLayout['tabs'] as List<dynamic>;
            final selectedTabLink = tabs[index]['link'] as String;
            if (
              selectedTabLink.toLowerCase() == "#" ||
              selectedTabLink.toLowerCase() == "more"
            ) {
              if (webViewControllers.isNotEmpty) {
                GlobalWebViewController globalWebViewController = webViewControllers.last;
                InAppWebViewController? controller = globalWebViewController.controller;
                void Function()? customLastGoBack = globalWebViewController.customLastGoBack;

                if (controller != null) {
                    if (customLastGoBack != null) {
                      customLastGoBack.call();
                      webViewControllers.removeLast();
                      setState(() {
                        _webViewControllers[currentPageIndex] = null; // update current controller
                      });
                  }
                }
              }
            }
            if (index == currentPageIndex) {
              // User tapped the current tab again
              final currentController = _webViewControllers[index];

              if (currentController != null) {
                try {
                  bool canGoBack = await currentController.canGoBack();
                  while (canGoBack) {
                    await currentController.goBack();
                    canGoBack = await currentController.canGoBack();
                  }
                  print("Navigated all the way back in WebView for tab $index");
                } catch (e) {
                  print('Error on going back all the way: $e');
                }
              } else {
              }
            } else {
              // User tapped a different tab, just switch to it
              setState(() {
                currentPageIndex = index;
              });
            }
        },
        indicatorColor: HexColor.fromHex(tabs[currentPageIndex]['color']),
          selectedIndex: currentPageIndex,
          destinations: [
            for (var tab in tabs)
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
                label: tab['text'],
              ),
          ],
        ),
        body: IndexedStack(
          index: currentPageIndex,
          children: _tabWidgets.cast<Widget>(),
        ),
      ),
    );
  }}

class SecondSplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double size = constraints.maxWidth < constraints.maxHeight
              ? constraints.maxWidth
              : constraints.maxHeight;

          double imageSize = size * 0.75;

          return Center(
            child: Image.asset(
              'assets/icon/splash2.png',
              width: imageSize,
              height: imageSize,
              fit: BoxFit.contain,
            ),
          );
        },
      ),
    );
  }
}


Future<void> initGoogleCast() async {
  if (Platform.isAndroid) {
    return;
  }

  // Use the default Cast application ID or your custom one
  const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
  GoogleCastOptions? options;
  
  if (Platform.isIOS) {
    options = IOSGoogleCastOptions(
      GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId),
    );
  } else if (Platform.isAndroid) {
    options = GoogleCastOptionsAndroid(
      appId: appId,
    );
  }
  
  // Initialize the Google Cast context
  GoogleCastContext.instance.setSharedInstanceWithOptions(options!);
}

void _showCastDevicesDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text("Select Cast Device"),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<List<GoogleCastDevice>>(
            stream: GoogleCastDiscoveryManager.instance.devicesStream,
            builder: (context, snapshot) {
              final devices = snapshot.data ?? [];
              if (devices.isEmpty) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "No Cast Devices Found",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Make sure your devices are on the same network and try again.",
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              }

              return ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return ListTile(
                    title: Text(device.friendlyName),
                    subtitle: Text(device.modelName ?? 'Unknown Model'),
                    onTap: () async {
                      Navigator.of(context).pop();
                      try {
                        await GoogleCastSessionManager.instance.startSessionWithDevice(device);
                        print("Connected to ${device.friendlyName}");
                      } catch (e) {
                        print("Failed to connect: $e");
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            child: Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    },
  );
}
