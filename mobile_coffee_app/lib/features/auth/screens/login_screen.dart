import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // 🔥 TAMBAHAN IMPORT SECURE STORAGE

import '../../../shared/layout/main_navigation_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../../../core/config/api_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  final LocalAuthentication auth = LocalAuthentication();
  bool canCheckBiometrics = false;
  List<BiometricType> availableBiometrics = [];
  
  // 🔥 TAMBAHAN INSTANCE SECURE STORAGE
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    checkBiometrics(); 
  }

  // --- LOGIKA CEK BIOMETRIK (TIDAK DIUBAH) ---
  Future<void> checkBiometrics() async {
    try {
      canCheckBiometrics = await auth.canCheckBiometrics;
      if (canCheckBiometrics) {
        availableBiometrics = await auth.getAvailableBiometrics();
        if (mounted) setState(() {});
      }
    } catch (e) {
      print("Error cek biometrik: $e");
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- LOGIKA LOGIN MANUAL (DENGAN TAMBAHAN SIMPAN KREDENSIAL) ---
  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email dan Password wajib diisi!"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "email": _emailController.text,
              "password": _passwordController.text,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', responseData['token']);

        if (responseData['user'] != null) {
          await prefs.setString(
            'user_name',
            responseData['user']['nama'] ?? "User",
          );
          await prefs.setString(
            'user_email',
            responseData['user']['email'] ?? _emailController.text,
          );
        }

        // 🔥 TAMBAHAN: SIMPAN EMAIL DAN PASSWORD DENGAN AMAN DI SECURE STORAGE
        await _secureStorage.write(key: 'saved_email', value: _emailController.text);
        await _secureStorage.write(key: 'saved_password', value: _passwordController.text);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? "Login Berhasil!"),
            backgroundColor: Colors.brown,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? "Gagal Login")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: Tidak dapat terhubung ke server ($e)")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIKA BIOMETRIK LOGIN (DIUBAH AGAR AUTO-LOGIN MENGGUNAKAN DATA TERSIMPAN) ---
  Future<void> _handleBiometricLogin() async {
    try {
      String reason = availableBiometrics.contains(BiometricType.face)
          ? 'Gunakan Face ID untuk masuk ke Caffio App'
          : 'Gunakan sidik jari untuk masuk ke Caffio App';

      bool authenticated = await auth.authenticate(localizedReason: reason);

      if (authenticated) {
        setState(() => _isLoading = true);

        // 🔥 TAMBAHAN: AMBIL KREDENSIAL YANG TERSIMPAN
        String? savedEmail = await _secureStorage.read(key: 'saved_email');
        String? savedPassword = await _secureStorage.read(key: 'saved_password');

        if (savedEmail != null && savedPassword != null) {
          // Lakukan request login otomatis ke API menggunakan data tersimpan
          final response = await http.post(
            Uri.parse('${ApiConfig.baseUrl}/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "email": savedEmail,
              "password": savedPassword,
            }),
          ).timeout(const Duration(seconds: 10));

          final responseData = jsonDecode(response.body);

          if (response.statusCode == 200) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('token', responseData['token']);
            if (responseData['user'] != null) {
              await prefs.setString('user_name', responseData['user']['nama'] ?? "User");
              await prefs.setString('user_email', responseData['user']['email'] ?? savedEmail);
            }

            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
            );
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Sesi bermasalah. Silakan login manual.")),
            );
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Belum ada akun yang tersimpan. Login manual terlebih dahulu.")),
          );
        }
        
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error Biometrik: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI BARU (CAFFIO APP STYLE) - TIDAK ADA PERUBAHAN ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], 
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- LOGO & HEADER ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.brown[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_cafe,
                  size: 70,
                  color: Colors.brown,
                ),
              ),
              const SizedBox(height: 25),
              const Text(
                "Welcome Back",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Sign in to continue to Caffio App",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),

              // --- FORM EMAIL ---
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email",
                  hintText: "Enter your email",
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: Colors.brown,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(
                      color: Colors.brown,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- FORM PASSWORD ---
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  hintText: "Enter your password",
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: Colors.brown,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(
                      color: Colors.brown,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              // --- LUPA PASSWORD ---
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    "Forgot Password?",
                    style: TextStyle(
                      color: Colors.brown,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // --- TOMBOL LOGIN ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.brown),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.brown[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _handleLogin,
                        child: const Text(
                          "Login",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 20),

              // --- TOMBOL REGISTER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account?",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    ),
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(
                        color: Colors.brown,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),

              // --- BIOMETRIK LOGIN ---
              if (canCheckBiometrics) ...[
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        "Or sign in with",
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _isLoading ? null : _handleBiometricLogin,
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      availableBiometrics.contains(BiometricType.face)
                          ? Icons.face
                          : Icons.fingerprint,
                      size: 40,
                      color: Colors.brown[700],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}