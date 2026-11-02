import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models.dart';

/// 大屏选集面板：方向键移动、OK 播放、返回键关闭。
///
/// 电视端不能用 [EpisodeGrid]——它依赖手势与 InkWell 的触摸焦点，
/// 遥控器的方向键在播放页会被外层 Focus 先吃掉。这里自己维护焦点索引，
/// 只用一个 [Focus] 节点，避免为上百集创建上百个 FocusNode。
class TvEpisodePanel extends StatefulWidget {
  const TvEpisodePanel({
    super.key,
    required this.episodes,
    required this.current,
    required this.onPick,
    required this.onClose,
  });

  final List<Episode> episodes;
  final int current;
  final ValueChanged<int> onPick;
  final VoidCallback onClose;

  @override
  State<TvEpisodePanel> createState() => _TvEpisodePanelState();
}

class _TvEpisodePanelState extends State<TvEpisodePanel> {
  static const _cellHeight = 56.0;
  static const _gap = 10.0;
  static const _inset = 22.0;
  static const _minCellWidth = 86.0;

  final _focus = FocusNode(debugLabel: 'tv-episodes');
  final _scroll = ScrollController();

  late int _index = widget.current.clamp(0, math.max(0, widget.episodes.length - 1));
  int _columns = 6;
  double _viewport = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _reveal(animate: false);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  double get _rowExtent => _cellHeight + _gap;

  void _move(int delta) {
    final next = (_index + delta).clamp(0, widget.episodes.length - 1);
    if (next == _index) return;
    setState(() => _index = next);
    _reveal();
  }

  void _reveal({bool animate = true}) {
    if (!_scroll.hasClients || _viewport <= 0) return;
    final row = _index ~/ _columns;
    final top = _inset + row * _rowExtent;
    final position = _scroll.position;
    final offset = position.pixels;
    final target = top < offset
        ? top - _inset
        : top + _cellHeight > offset + _viewport
        ? top + _cellHeight - _viewport + _inset
        : null;
    if (target == null) return;
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (animate) {
      _scroll.animateTo(
        clamped,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    } else {
      _scroll.jumpTo(clamped);
    }
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _move(-1);
      case LogicalKeyboardKey.arrowRight:
        _move(1);
      case LogicalKeyboardKey.arrowUp:
        _move(-_columns);
      case LogicalKeyboardKey.arrowDown:
        _move(_columns);
      case LogicalKeyboardKey.pageUp:
        _move(-_columns * 3);
      case LogicalKeyboardKey.pageDown:
        _move(_columns * 3);
      case LogicalKeyboardKey.home:
        _move(-widget.episodes.length);
      case LogicalKeyboardKey.end:
        _move(widget.episodes.length);
      case LogicalKeyboardKey.enter ||
          LogicalKeyboardKey.numpadEnter ||
          LogicalKeyboardKey.select ||
          LogicalKeyboardKey.gameButtonA:
        widget.onPick(_index);
      case LogicalKeyboardKey.escape || LogicalKeyboardKey.goBack:
        widget.onClose();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = math.min(size.width * .68, 820.0);
    final height = math.min(size.height * .82, 660.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xB3000000)),
        Center(
          child: Focus(
            focusNode: _focus,
            autofocus: true,
            onKeyEvent: _key,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: const Color(0xF5151416),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 48,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(theme),
                  Expanded(child: _grid(theme)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(ThemeData theme) {
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_inset, 18, _inset, 10),
      child: Row(
        children: [
          Icon(Icons.grid_view_rounded, size: 22, color: colors.primary),
          const SizedBox(width: 10),
          const Text(
            '选集',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '共 ${widget.episodes.length} 集',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .55),
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Text(
            '方向键选择 · OK 播放 · 返回键关闭',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .38),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(ThemeData theme) => LayoutBuilder(
    builder: (context, constraints) {
      _columns = math.max(
        1,
        ((constraints.maxWidth - _inset * 2 + _gap) / (_minCellWidth + _gap))
            .floor(),
      );
      _viewport = constraints.maxHeight;
      final rows = (widget.episodes.length / _columns).ceil();
      return ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(_inset, _inset, _inset, _inset),
        itemExtent: _rowExtent,
        itemCount: rows,
        itemBuilder: (context, row) => Padding(
          padding: const EdgeInsets.only(bottom: _gap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: _gap,
            children: [
              for (
                var index = row * _columns;
                index < (row + 1) * _columns;
                index++
              )
                Expanded(
                  child: index < widget.episodes.length
                      ? _cell(theme, index)
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _cell(ThemeData theme, int index) {
    final colors = theme.colorScheme;
    final episode = widget.episodes[index];
    final focused = index == _index;
    final current = index == widget.current;
    final watched = index < widget.current;
    final foreground = focused
        ? colors.onPrimary
        : current
        ? colors.onPrimaryContainer
        : Colors.white.withValues(alpha: watched ? .5 : .92);
    final radius = BorderRadius.circular(12);
    return AnimatedScale(
      scale: focused ? 1.06 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: focused
              ? colors.primary
              : current
              ? colors.primaryContainer
              : Colors.white.withValues(alpha: .08),
          borderRadius: radius,
          border: Border.all(
            color: focused || current
                ? Colors.transparent
                : Colors.white.withValues(alpha: .06),
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 4,
          children: [
            if (current)
              Icon(Icons.equalizer_rounded, size: 14, color: foreground),
            Text(
              '${episode.number}',
              style: TextStyle(
                color: foreground,
                fontSize: 17,
                fontWeight: current || focused
                    ? FontWeight.w700
                    : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
