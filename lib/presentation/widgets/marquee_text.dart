import 'dart:async';
import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final bool isFocused;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.isFocused = false,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  bool _isScrolling = false;

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused != oldWidget.isFocused) {
      if (widget.isFocused) {
        _startMarquee();
      } else {
        _stopMarquee();
      }
    }
  }

  void _startMarquee() {
    _stopMarquee();
    _isScrolling = true;
    _scroll();
  }

  void _stopMarquee() {
    _timer?.cancel();
    _isScrolling = false;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  void _scroll() async {
    if (!mounted || !_scrollController.hasClients || !_isScrolling) return;

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    if (maxScrollExtent > 0) {
      await Future.delayed(const Duration(seconds: 1)); // Wait before scrolling
      if (!mounted || !_isScrolling) return;

      final duration = Duration(
        milliseconds: (maxScrollExtent * 30).toInt(),
      ); // Adjust speed here

      await _scrollController.animateTo(
        maxScrollExtent,
        duration: duration,
        curve: Curves.linear,
      );

      if (!mounted || !_isScrolling) return;

      await Future.delayed(const Duration(seconds: 1)); // Wait at the end
      if (!mounted || !_isScrolling) return;

      _scrollController.jumpTo(0.0);
      _scroll(); // Loop
    }
  }

  @override
  void dispose() {
    _stopMarquee();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style, maxLines: 1),
    );
  }
}
