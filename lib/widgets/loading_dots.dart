import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key});

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    // 3 Dots ke liye 3 Controllers
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      )..repeat(reverse: true); // Loop mein chalta rahe
    });

    // Staggered Animation (Aik ke baad aik jump karega)
    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 10.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    // Delay start for wave effect
    Future.delayed(const Duration(milliseconds: 0), () => _controllers[0].forward());
    Future.delayed(const Duration(milliseconds: 200), () => _controllers[1].forward());
    Future.delayed(const Duration(milliseconds: 400), () => _controllers[2].forward());
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              transform: Matrix4.translationValues(0, -_animations[index].value, 0), // Jump Logic
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.white, // Dot Color
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}