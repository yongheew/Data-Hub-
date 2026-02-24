import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SignUpPage extends StatefulWidget {
  SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  String? _selectedGender;
  DateTime? _selectedBirthDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                const Text(
                  "Sign Up",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  "Please fill in your details",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),

                const SizedBox(height: 40),

                _buildTextField(hintText: "Your Name", obscureText: false),
                const SizedBox(height: 20),

                _buildTextField(hintText: "Your E-mail", obscureText: false),
                const SizedBox(height: 20),

                _buildTextField(
                  hintText: "Create your Password",
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.black45,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 20),

                _buildTextField(
                  hintText: "Re-type your Password",
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.black45,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F3F3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedGender,
                            hint: const Text(
                              "Gender",
                              style: TextStyle(
                                color: Colors.black38,
                                fontSize: 14,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: "Male",
                                child: Text("Male"),
                              ),
                              DropdownMenuItem(
                                value: "Female",
                                child: Text("Female"),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedGender = value;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime(2000),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );

                          if (pickedDate != null) {
                            setState(() {
                              _selectedBirthDate = pickedDate;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F3F3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _selectedBirthDate == null
                                ? "Birth"
                                : "${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}",
                            style: TextStyle(
                              color: _selectedBirthDate == null
                                  ? Colors.black38
                                  : Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Checkbox(
                      value: _agreeToTerms,
                      onChanged: (value) {
                        setState(() {
                          _agreeToTerms = value ?? false;
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        "I agree to the Terms and Conditions",
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/home');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F436E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Create your Account",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Already have an account? Sign In now",
                  style: TextStyle(fontSize: 13, color: Colors.black45),
                ),

                const SizedBox(height: 40),
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
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF3F3F3),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
