import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../utils/WebView.dart';
import '../utils/Color.dart';
import '../utils/AppImage.dart';

import '../global/AppState.dart';

class HomeScreen extends StatefulWidget {
  final void Function(dynamic)? onWebViewCreated;
  const HomeScreen({super.key, this.onWebViewCreated});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  String? _url;

  void _handleLinkClicked(String linkUrl) {
    setState(() {
      _url = linkUrl;
    });
  }

  void customLastGoBack() {
    setState(() {
      _url = null;
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> appLayout = AppStateScope.of(context).appLayout;

   var homeTab;

    for (var tab in appLayout['tabs']!) {
      if (tab['text']!.toLowerCase() == "home") {
        homeTab = tab;
      }
    }
    if (homeTab == null) {
      return Center(
        child: Text("No 'Home' Tab was found on tabs")
      );
    }

    if (_url == null) {
      final List<List<List<Map<String, dynamic>>>> matrixList = [
        for (var section in homeTab['sections']!)
          flatToMatrix((section['buttons']! as List)
            .cast<Map<String, dynamic>>()
          )
      ];

      final List<Map<String, dynamic>> headers = [
        for (var section in homeTab['sections']!)
        {
          'title': section['title']!,
          'underlineColor': section['underlineColor']!,
        }
      ];

      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 0,
          vertical: 24
        ),
        child: HomeLayoutWidget(
          matrixList: matrixList,
          headers: headers,
          handleLinkClicked: _handleLinkClicked,
        )
      );
    }

    else {
      return WebView(url: _url!, customLastGoBack: customLastGoBack, onWebViewCreated: this.widget.onWebViewCreated);
    }
  }

  List<List<Map<String, dynamic>>> flatToMatrix(
    List<Map<String, dynamic>> buttons
  ) {
    int rows = sqrt(buttons.length).toInt();
    int columns = (buttons.length / rows).toInt();
    List<List<Map<String, dynamic>>> matrix = [];
    List<Map<String, dynamic>> current = [];
    int current_idx = 0;

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        current.add(buttons[current_idx]);
        current_idx += 1;
      }
      matrix.add(current);
      current = [];
    }
    return matrix;
  }
}

class HomeLayoutWidget extends StatelessWidget {
  List<Map<String, dynamic>> headers;
  List<List<List<Map<String, dynamic>>>> matrixList;
  final void Function(String) handleLinkClicked;

  HomeLayoutWidget({
    super.key,
    required this.matrixList,
    required this.headers,
    required this.handleLinkClicked,
  });

  final double headerHeight = 40;
  final double verticalMargin = 18;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int numMatrices = matrixList.length;

        double totalVerticalMargin = (numMatrices - 1) * verticalMargin;
        double totalHeaderHeight = numMatrices * headerHeight;

        double usableHeight =
            constraints.maxHeight - totalVerticalMargin - totalHeaderHeight;

        double matrixHeight = usableHeight / numMatrices;
        double matrixWidth = constraints.maxWidth;

        int maxRows = 0;
        int maxColumns = 0;

        int totalRows = 0;
        for (var matrix in matrixList) {
          int rows = matrix.length;
          int cols = matrix.map((row) => row.length).reduce(
            (a, b) => a > b ? a : b
          );
          totalRows += rows;
          maxRows = max(maxRows, rows);
          maxColumns = max(maxColumns, cols);
        }
        
        double cellHeight = usableHeight / totalRows;
        double cellWidth = matrixWidth / maxColumns;

        return Column(
          children: List.generate(numMatrices, (index) {
            final matrix = matrixList[index];
            final header = headers[index]['title'];
            final underlineColor = headers[index]['underlineColor'];

            return Container(
              margin: EdgeInsets.only(
                bottom: index < numMatrices - 1 ? verticalMargin : 0
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: headerHeight,
                    child: IntrinsicWidth(
                      child: Column(
                        children: [
                          Text(
                            header,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            height: 3,
                            color: HexColor.fromHex(underlineColor)
                          ),
                        ],
                      ),
                    ),
                  ),
                  MatrixGrid(
                    matrix: matrix,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight,
                    handleLinkClicked: handleLinkClicked,
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

class MatrixGrid extends StatelessWidget {
  final List<List<Map<String, dynamic>>> matrix;
  final double cellWidth;
  final double cellHeight;
  final void Function(String) handleLinkClicked;

  const MatrixGrid({
    super.key,
    required this.matrix,
    required this.cellWidth,
    required this.cellHeight,
    required this.handleLinkClicked,
  });

  @override
  Widget build(BuildContext context) {
    int rows = matrix.length;
    int cols = matrix.map((row) => row.length).reduce((a, b) => a > b ? a : b);
    final String loaded = AppStateScope.of(context).loaded!;

    return SizedBox(
      width: cellWidth * cols,
      height: cellHeight * rows,
      child: Column(
        children: List.generate(rows, (i) {
          return Row(
            children: List.generate(cols, (j) {

              final cell = (i < matrix.length && j < matrix[i].length)
                  ? matrix[i][j]
                  : null;

              return GestureDetector(
                onTap: () {
                  if (cell != null) {
                    handleLinkClicked(cell['link']);
                  }
                },
                child: Container(

                  width: cellWidth,
                  height: cellHeight,
                  /*
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  */
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2
                  ),
                  child: cell == null 
                    ? const SizedBox.shrink()
                    : Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: AppImage(
                                  path: cell['icon'],
                                  color: HexColor.fromHex(cell['color']),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                cell['text'],
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),            
                )
              );
            }),
          );
        }),
      ),
    );
  }
}

