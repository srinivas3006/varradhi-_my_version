import 'package:flutter/material.dart';

typedef ParallaxPageFlipBuilder = Widget Function(
  BuildContext context,
  int index,
  bool isCurrent,
  double dragDelta,
  double dragProgress,
  double matchCutProgress,
);

class ParallaxPageFlip extends StatefulWidget {
  final int itemCount;
  final ParallaxPageFlipBuilder itemBuilder;
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;
  final Duration flingDuration;
  final Duration matchCutDuration;
  final double commitThreshold;
  final double flingVelocity;

  const ParallaxPageFlip({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.initialIndex = 0,
    this.onPageChanged,
    this.flingDuration = const Duration(milliseconds: 300),
    this.matchCutDuration = const Duration(milliseconds: 200),
    this.commitThreshold = 0.35,
    this.flingVelocity = 800.0,
  });

  @override
  State<ParallaxPageFlip> createState() => _ParallaxPageFlipState();
}

class _ParallaxPageFlipState extends State<ParallaxPageFlip> with TickerProviderStateMixin {
  late int _index;
  late AnimationController _dragCtrl;
  late AnimationController _matchCutCtrl;
  
  double _dragStartY = 0;
  double _height = 0;
  int _direction = 0; // -1 next, 1 prev, 0 idle

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    
    _dragCtrl = AnimationController(vsync: this, duration: widget.flingDuration)
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (_dragCtrl.value == 1.0) {
            // Drag completed! Trigger match cut.
            _matchCutCtrl.forward(from: 0.0);
          } else {
            // Dismissed
            setState(() => _direction = 0);
          }
        }
      });

    _matchCutCtrl = AnimationController(vsync: this, duration: widget.matchCutDuration)
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // Transition fully complete
          setState(() {
            if (_direction == -1 && _index < widget.itemCount - 1) _index++;
            else if (_direction == 1 && _index > 0) _index--;
            _direction = 0;
          });
          _dragCtrl.value = 0;
          _matchCutCtrl.value = 0;
          widget.onPageChanged?.call(_index);
        }
      });
  }

  @override
  void dispose() {
    _dragCtrl.dispose();
    _matchCutCtrl.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails d) {
    if (_dragCtrl.isAnimating || _matchCutCtrl.isAnimating) return;
    _dragStartY = d.globalPosition.dy;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_height == 0 || _dragCtrl.isAnimating || _matchCutCtrl.isAnimating) return;
    final dy = d.globalPosition.dy - _dragStartY;

    if (_direction == 0) {
      if (dy < -4 && _index < widget.itemCount - 1) {
        _direction = -1; // next
      } else if (dy > 4 && _index > 0) {
        _direction = 1; // prev
      } else {
        return;
      }
    }

    final progress = (dy.abs() / _height).clamp(0.0, 1.0);
    _dragCtrl.value = progress;
  }

  void _onDragEnd(DragEndDetails d) {
    if (_direction == 0 || _matchCutCtrl.isAnimating) return;
    
    final velocity = d.velocity.pixelsPerSecond.dy;
    final flungForward = (_direction == -1 && velocity < -widget.flingVelocity) ||
        (_direction == 1 && velocity > widget.flingVelocity);
    final pastThreshold = _dragCtrl.value > widget.commitThreshold;

    if (flungForward || pastThreshold) {
      _dragCtrl.animateTo(1.0, curve: Curves.easeOutCubic);
    } else {
      _dragCtrl.animateBack(0.0, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _height = constraints.maxHeight;
        final dragProgress = _dragCtrl.value;
        final matchCutProgress = _matchCutCtrl.value;
        final dragDelta = _direction != 0 ? dragProgress * _height * _direction : 0.0;
        
        Widget stack;
        
        final currentWidget = widget.itemBuilder(
          context, 
          _index,
          true, // isCurrent
          dragDelta, 
          dragProgress,
          matchCutProgress,
        );

        if (_direction == -1 && _index < widget.itemCount - 1) {
          // Swipe up (Next) -> Next card is below
          final nextWidget = widget.itemBuilder(
            context,
            _index + 1,
            false, // isIncoming
            _height + dragDelta, // offset logic
            1.0 - dragProgress,
            matchCutProgress,
          );
          stack = Stack(
            fit: StackFit.expand,
            children: [
              nextWidget,
              currentWidget, // Current on top
            ],
          );
        } else if (_direction == 1 && _index > 0) {
          // Swipe down (Prev) -> Prev card is above
          final prevWidget = widget.itemBuilder(
            context,
            _index - 1,
            false,
            -_height + dragDelta,
            1.0 - dragProgress,
            matchCutProgress,
          );
          stack = Stack(
            fit: StackFit.expand,
            children: [
              currentWidget,
              prevWidget, // Prev comes in on top!
            ],
          );
        } else {
          stack = currentWidget;
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          child: ClipRect(child: stack),
        );
      },
    );
  }
}
