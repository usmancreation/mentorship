import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // <--- IMPORT ADDED
import '../widgets/flickr_loading.dart';
import 'signup_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Request Notification Permission IMMEDIATELY
    _requestPermission();

    // 2. Logo Pulse Animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 3. Timer with Login Check
    _checkLoginAndNavigate();
  }

  // --- NEW PERMISSION FUNCTION ---
  void _requestPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    print("Notification Permission Requested on Splash Screen");
  }

  // Login Check Logic
  void _checkLoginAndNavigate() {
    Timer(const Duration(seconds: 5), () async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool? isLoggedIn = prefs.getBool('isLoggedIn');

      if (mounted) {
        if (isLoggedIn == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // --- LAYER 1: STATIC GRADIENT BACKGROUND ---
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF2E3A59), // Deep Blue
                      Color(0xFF162032), // Darker Blue
                    ],
                  ),
                ),
              ),
            ),

            // --- LAYER 2: BACKGROUND PATTERN ---
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: Center(child: const BackgroundPattern()),
              ),
            ),

            // --- LAYER 3: CONTENT ---
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),

                  // A. PULSE LOGO
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.15), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 40,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: Container(
                        width: size.width * 0.35,
                        height: size.width * 0.35,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            "assets/images/logo.jpeg",
                            fit: BoxFit.cover,
                            width: size.width * 0.35,
                            height: size.width * 0.35,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Colors.red,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.05),

                  // B. TYPEWRITER TEXT
                  SizedBox(
                    height: 50,
                    child: TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: "Mentorship Hub".length),
                      duration: const Duration(milliseconds: 1500),
                      builder: (context, value, child) {
                        String text = "Mentorship Hub";
                        return Text(
                          text.substring(0, value),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 5),

                  // C. TAGLINE
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(seconds: 3),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Text(
                          "Master Your Future",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: Colors.tealAccent,
                            letterSpacing: 3.0,
                            fontWeight: FontWeight.w300
                          ),
                        ),
                      );
                    },
                  ),

                  const Spacer(),

                  // D. FLICKR LOADER
                  const Padding(
                    padding: EdgeInsets.only(bottom: 60.0),
                    child: FlickrLoading(size: 50),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- BACKGROUND PATTERN ---
class BackgroundPattern extends StatelessWidget {
  const BackgroundPattern({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 80,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            crossAxisSpacing: 20,
            mainAxisSpacing: 30,
          ),
          itemBuilder: (context, index) {
            return Transform.rotate(
              angle: index % 2 == 0 ? 0.2 : -0.2,
              child: const Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 30,
              ),
            );
          },
        );
      }
    );
  }
}