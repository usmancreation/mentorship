import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class FlickrLoading extends StatefulWidget {
  final double size;
  const FlickrLoading({super.key, this.size = 50.0});

  @override
  State<FlickrLoading> createState() => _FlickrLoadingState();
}

class _FlickrLoadingState extends State<FlickrLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), 
    )..repeat(); 

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final double dx = (widget.size / 2) * androidFlickrMath(_animation.value);
          bool dot1OnTop = _animation.value < 0.5;

          return Stack(
            alignment: Alignment.center,
            children: [
              // --- DOT 1 (Yellow - Theme Color) ---
              Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.scale(
                  scale: dot1OnTop ? 0.7 : 1.0, 
                  child: Container(
                    width: widget.size / 2.2,
                    height: widget.size / 2.2,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryYellow, // <--- FIXED: Yellow Color
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
                    ),
                  ),
                ),
              ),

              // --- DOT 2 (White - Contrast) ---
              Transform.translate(
                offset: Offset(-dx, 0),
                child: Transform.scale(
                  scale: dot1OnTop ? 1.0 : 0.7, 
                  child: Container(
                    width: widget.size / 2.2,
                    height: widget.size / 2.2,
                    decoration: const BoxDecoration(
                      color: Colors.white, 
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double androidFlickrMath(double t) {
    return (t <= 0.5) ? 2 * t : 2 * (1 - t);
  }
}