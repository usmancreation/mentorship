import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';
import '../widgets/fade_in_slide.dart';
import 'signup_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;

  Future<void> _loginUser() async {
    // 1. Validation
    if (_emailController.text.isEmpty || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. API Call
      var response = await http.post(
        Uri.parse('https://techrisepk.com/mentor/studentauth/signin.php'),
        body: {
          'email': _emailController.text,
          'password': _passController.text
        },
      );

      var jsonResponse = json.decode(response.body);

      // 3. Check Success
      if (jsonResponse['status'] == 'success') {
        
        // --- SHARED PREFERENCES LOGIC START ---
        SharedPreferences prefs = await SharedPreferences.getInstance();
        
        // Data save kar rahe hain taake app restart hone par bhi login rahe
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId', jsonResponse['user']['id'].toString());
        await prefs.setString('userName', jsonResponse['user']['name'].toString());
        await prefs.setString('userEmail', jsonResponse['user']['email'].toString());
        
        // Image check (agar null ho to empty string)
        String userImage = jsonResponse['user']['image'] ?? "";
        await prefs.setString('userImage', userImage);
        // --- SHARED PREFERENCES LOGIC END ---

        if (!mounted) return; // Check context validity

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.green,
          content: Text("Welcome ${jsonResponse['user']['name']}!"),
        ));

        // 4. Navigation
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        });

      } else {
        // Login Failed
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red,
          content: Text(jsonResponse['message']),
        ));
      }
    } catch (e) {
      print("Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection Error. Check Internet.")),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.primaryYellow,
      body: Stack(
        children: [
          // --- TOP SECTION (Yellow) ---
          Positioned(
            top: 0, left: 0, right: 0,
            height: size.height * 0.75,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: size.height * 0.1),

                  // --- ANIMATED HEADERS ---
                  const FadeInSlide(delay: 0.1, child: Text("Welcome to", style: TextStyle(fontSize: 16, color: AppColors.primaryBlack))),
                  const FadeInSlide(delay: 0.2, child: Text("MENTORSHIP", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primaryBlack, letterSpacing: 1))),
                  const FadeInSlide(delay: 0.3, child: Text("Please Login To Continue", style: TextStyle(fontSize: 14, color: AppColors.primaryBlack))),

                  const SizedBox(height: 40),

                  // --- ANIMATED INPUTS ---
                  FadeInSlide(delay: 0.4, child: _buildInput(_emailController, "Email / Username", false)),
                  const SizedBox(height: 16),
                  FadeInSlide(delay: 0.5, child: _buildInput(_passController, "Password", true)),

                  const SizedBox(height: 24),

                  // --- ANIMATED LOGIN BUTTON ---
                  FadeInSlide(
                    delay: 0.6,
                    child: GestureDetector(
                      onTap: _isLoading ? null : _loginUser,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlack,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 5))],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const CircularProgressIndicator(color: AppColors.primaryYellow)
                              : const Text("LOGIN", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryYellow)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- BOTTOM CURVE & SIGNUP BUTTON ---
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: size.height * 0.28,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                ClipPath(
                  clipper: BottomCurveClipper(),
                  child: Container(color: AppColors.primaryBlack, height: double.infinity),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 30),
                    const FadeInSlide(delay: 0.8, child: Text("OR", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 15),

                    FadeInSlide(
                      delay: 0.9,
                      child: GestureDetector(
                        onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SignupScreen())),
                        child: Container(
                          width: size.width * 0.8,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primaryYellow,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                          ),
                          child: const Center(
                            child: Text("SIGN UP", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint, bool isPass) {
    return TextField(
      controller: controller,
      obscureText: isPass,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.inputYellow,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textYellow, fontWeight: FontWeight.bold),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: AppColors.primaryBlack, width: 0.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: AppColors.primaryBlack, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}

class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.moveTo(0, 60);
    path.quadraticBezierTo(size.width / 2, 0, size.width, 60);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}