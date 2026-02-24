import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:datahub/screens/signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                /// Title
                const Text(
                  "Welcome to\nDataHub",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 12),

                /// Subtitle
                const Text(
                  "To continue using this app,\nplease sign in first.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),

                const SizedBox(height: 32),

                /// Illustration
                SvgPicture.asset(
                  "assets/illustration.svg",
                  height: 220,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 32),

                /// Email Field
                _buildTextField(
                  hintText: "Email or Username",
                  obscureText: false,
                ),

                const SizedBox(height: 16),

                /// Password Field
                _buildTextField(
                  hintText: "Password",
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 8),

                /// Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text(
                      "Forgot your Password?",
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                /// Sign In Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF243C66),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Sign In",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// Sign Up
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Didn't have any Account? ",
                      style: TextStyle(fontSize: 12),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SignUpPage()),
                        );
                      },
                      child: const Text(
                        "Sign Up now",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hintText,
    required bool obscureText,
    Widget? suffixIcon,
  }) {
    return TextField(
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black38),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
