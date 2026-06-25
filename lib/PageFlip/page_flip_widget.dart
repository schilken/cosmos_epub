import 'package:flutter/material.dart';

//ignore: must_be_immutable
class PageFlipWidget extends StatefulWidget {
  PageFlipWidget({
    Key? key,
    this.duration = const Duration(milliseconds: 300),
    this.backgroundColor = Colors.white,
    required this.children,
    this.initialIndex = 0,
    this.lastPage,
    required this.onPageFlip,
    this.onLastPageTap,
  })  : assert(initialIndex < children.length,
            'initialIndex cannot be greater than children length'),
        super(key: key);

  final Color backgroundColor;
  final List<Widget> children;
  final Duration duration;
  final int initialIndex;
  final Widget? lastPage;

  /// Called on page flip. [pageIndex] is the new page, [isForward] is direction.
  Function(int pageIndex, {bool? isForward}) onPageFlip;

  /// Called when the user taps the right edge while already on the last page.
  final VoidCallback? onLastPageTap;

  @override
  PageFlipWidgetState createState() => PageFlipWidgetState();
}

class PageFlipWidgetState extends State<PageFlipWidget>
    with TickerProviderStateMixin {
  late List<Widget> _effectiveChildren;
  int _currentPage = 0;
  late AnimationController _controller;
  bool _forward = false;
  Offset? _tapDownPos;

  bool get _isLastPage => _currentPage >= _effectiveChildren.length - 1;
  bool get _isFirstPage => _currentPage == 0;

  int get currentPage => _currentPage;

  void _buildEffectiveChildren() {
    _effectiveChildren = List.of(widget.children);
    if (widget.lastPage != null) {
      _effectiveChildren.add(widget.lastPage!);
    }
  }

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _buildEffectiveChildren();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _currentPage = _forward
                ? (_currentPage + 1).clamp(0, _effectiveChildren.length - 1)
                : (_currentPage - 1).clamp(0, _effectiveChildren.length - 1);
          });
          _controller.reset();
          widget.onPageFlip(_currentPage, isForward: _forward);
        }
      });
  }

  @override
  void didUpdateWidget(PageFlipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.children.length != oldWidget.children.length ||
        !identical(widget.children, oldWidget.children)) {
      _buildEffectiveChildren();
      _currentPage =
          widget.initialIndex.clamp(0, _effectiveChildren.length - 1);
      _controller.reset();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void nextPage() {
    if (_isLastPage) return;
    _forward = true;
    _controller.forward(from: 0);
  }

  void previousPage() {
    if (_isFirstPage) return;
    _forward = false;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, dimens) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) {
          _tapDownPos = e.localPosition;
          debugPrint(
              '[Bug1] PFW onPointerDown: pos=${e.localPosition}, isAnim=${_controller.isAnimating}, isLast=$_isLastPage, page=$_currentPage, effLen=${_effectiveChildren.length}');
        },
        onPointerUp: (e) {
          debugPrint(
              '[Bug1] PFW onPointerUp: tapDown=$_tapDownPos, localPos=${e.localPosition}, isAnim=${_controller.isAnimating}');
          if (_tapDownPos != null && !_controller.isAnimating) {
            final delta = (e.localPosition - _tapDownPos!).distance;
            debugPrint('[Bug1] PFW onPointerUp: delta=$delta');
            if (delta < 18) {
              final ratio = e.localPosition.dx / dimens.maxWidth;
              debugPrint(
                  '[Bug1] PFW onPointerUp: ratio=$ratio, isFirst=$_isFirstPage, isLast=$_isLastPage');
              if (ratio <= 0.2 && !_isFirstPage) {
                previousPage();
              } else if (ratio >= 0.8) {
                if (!_isLastPage) {
                  nextPage();
                } else {
                  debugPrint('[Bug1] onLastPageTap invoked');
                  widget.onLastPageTap?.call();
                }
              }
            }
          } else {
            debugPrint(
                '[Bug1] PFW onPointerUp SKIPPED: tapDownNull=${_tapDownPos == null}, isAnim=${_controller.isAnimating}');
          }
          _tapDownPos = null;
        },
        child: _buildPages(),
      ),
    );
  }

  Widget _buildPages() {
    if (_effectiveChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentWidget = _effectiveChildren[_currentPage];

    if (!_controller.isAnimating) {
      return currentWidget;
    }

    final nextIndex = (_forward ? _currentPage + 1 : _currentPage - 1)
        .clamp(0, _effectiveChildren.length - 1);
    final nextWidget = _effectiveChildren[nextIndex];

    final oldSlide = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(_forward ? -1.0 : 1.0, 0.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    final newSlide = Tween<Offset>(
      begin: Offset(_forward ? 1.0 : -1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    return Stack(
      fit: StackFit.expand,
      children: [
        SlideTransition(position: oldSlide, child: currentWidget),
        SlideTransition(position: newSlide, child: nextWidget),
      ],
    );
  }
}
