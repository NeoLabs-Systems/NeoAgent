// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

int _computerDisplayViewId = 0;

class ComputerDisplay extends StatefulWidget {
  const ComputerDisplay({super.key, required this.url});

  final String url;

  @override
  State<ComputerDisplay> createState() => _ComputerDisplayState();
}

class _ComputerDisplayState extends State<ComputerDisplay> {
  late String _viewType;
  late html.IFrameElement _frame;

  @override
  void initState() {
    super.initState();
    _registerFrame();
  }

  @override
  void didUpdateWidget(covariant ComputerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _frame.src = widget.url;
    }
  }

  void _registerFrame() {
    _viewType = 'neoagent-computer-display-${_computerDisplayViewId++}';
    _frame = html.IFrameElement()
      ..src = widget.url
      ..title = 'NeoAgent Linux computer'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = '0'
      ..style.backgroundColor = '#111111'
      ..allow = 'clipboard-read; clipboard-write'
      ..setAttribute('referrerpolicy', 'same-origin');
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _frame,
    );
  }

  @override
  void dispose() {
    _frame.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
