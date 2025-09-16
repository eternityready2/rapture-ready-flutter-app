import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../global/AppState.dart';
import '../global/Constants.dart';


class AppImage extends StatefulWidget {
  final String path;
  final double? width;
  final double? height;
  final Color? color;

  const AppImage({
    Key? key,
    required this.path,
    this.width,
    this.height,
    this.color,
  }) : super(key: key);

  @override
  _AppImageState createState() => _AppImageState();
}

class _AppImageState extends State<AppImage> {
  late Future<Uint8List> _futureBytes;
  Uint8List? _cachedBytes;
  String _loadType = "assets";
  String? _failed;

  @override
  void initState() {
    super.initState();
    _futureBytes = _loadImage(widget.path, _loadType);
  }

  Future<Uint8List> _loadImage(String path, String loadType) async {
    final AppImageCache imageCache = AppImageCache();

    if (loadType == "assets" || path.startsWith("/images")) {
      try {
        final bytes = await imageCache.readImageFromCache(path);
        return bytes;
      } catch (_) {
        final assetPath = "assets$path";
        ByteData byteData = await rootBundle.load(assetPath);
        final data = byteData.buffer.asUint8List();
        await imageCache.writeImageToCache(path, data);
        return data;
      }
    }

    print("loadtype $loadType $path");
    final response = await http.get(Uri.parse(
        path.startsWith('http') ? path : "${BACKEND_URL}/${path}"
    ));

    if (response.statusCode == 200) {
      await imageCache.writeImageToCache(path, response.bodyBytes);
      return response.bodyBytes;
    } else {
      throw Exception('Failed to load image, status: ${response.statusCode}');
    }
  }

  void _switchToNetworkLoad(Uint8List? currentData, [String? failedStage]) {
    if (mounted) {
      setState(() {
        _loadType = "network";
        _failed = failedStage;
        _cachedBytes = currentData;
        _futureBytes = _loadImage(widget.path, "network");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _futureBytes,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _cachedBytes != null ? _successWidget(_cachedBytes!) : _waitingWidget();
        } else if (snapshot.hasError) {
          if (_loadType == "assets" && _failed == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _switchToNetworkLoad(null, "assets");
            });
            return _waitingWidget();
          } else if (_loadType == "network" && _failed == null) {
            return _cachedBytes != null ? _successWidget(_cachedBytes!) : _failureWidget();
          }
          return _failureWidget();
        } else if (snapshot.hasData) {
          if (_loadType == "assets") {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _switchToNetworkLoad(snapshot.data, null);
            });
          }
          return _successWidget(snapshot.data!);
        }
        return _failureWidget();
      },
    );
  }

  Widget _successWidget(Uint8List data) {
    return RepaintBoundary(
      child: Image.memory(
        data,
        width: widget.width,
        height: widget.height,
        color: widget.color,
      ),
    );
  }

  Widget _waitingWidget() {
    return SizedBox(
      width: widget.width ?? 24,
      height: widget.height ?? 24,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _failureWidget() {
    return Icon(
      Icons.info,
      size: (widget.width != null && widget.height != null) ? min(widget.width!, widget.height!) : 24,
      color: Colors.red,
    );
  }
}

class AppImageCache {

  // Get cache directory path
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<Uint8List> readImageFromCache(String path) async {
    final localPath = await _localPath;
    final filename = path.replaceAll('/', '.');
    final file = File('$localPath/$filename');
    return await file.readAsBytes();
  }

  Future<File> writeImageToCache(String path, Uint8List bytes) async {
    final localPath = await _localPath;
    final filename = path.replaceAll('/', '.');
    final file = File('$localPath/$filename');
    return await file.writeAsBytes(bytes, flush: true);
  }
}
