import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../shared/layout/main_navigation_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../../../core/config/api_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  final LocalAuthentication auth = LocalAuthentication();
  bool canCheckBiometrics = false;
  List<BiometricType> availableBiometrics = [];

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ─── Design Tokens ──────────────────────────────────────
  static const _brown900 = Color(0xFF3E2723);
  static const _brown700 = Color(0xFF5D4037);
  static const _brown400 = Color(0xFF8D6E63);
  static const _cream = Color(0xFFFAF7F4);
  static const _cardBg = Color(0xFFFFFFFF);
  static const _inputBorder = Color(0xFFEEE8E4);
  static const _textHint = Color(0xFFBCAAA4);
  // ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    checkBiometrics();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

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
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnack("Email dan Password wajib diisi!", isError: true);
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
              'user_name', responseData['user']['nama'] ?? "User");
          await prefs.setString(
              'user_email',
              responseData['user']['email'] ?? _emailController.text);
        }
        await _secureStorage.write(
            key: 'saved_email', value: _emailController.text);
        await _secureStorage.write(
            key: 'saved_password', value: _passwordController.text);

        if (!mounted) return;
        _showSnack(responseData['message'] ?? "Login Berhasil!");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const MainNavigationScreen()),
        );
      } else {
        if (!mounted) return;
        _showSnack(responseData['message'] ?? "Gagal Login", isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack("Tidak dapat terhubung ke server", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBiometricLogin() async {
    try {
      String reason = availableBiometrics.contains(BiometricType.face)
          ? 'Gunakan Face ID untuk masuk ke Caffio App'
          : 'Gunakan sidik jari untuk masuk ke Caffio App';

      bool authenticated = await auth.authenticate(localizedReason: reason);

      if (authenticated) {
        setState(() => _isLoading = true);
        String? savedEmail = await _secureStorage.read(key: 'saved_email');
        String? savedPassword = await _secureStorage.read(key: 'saved_password');

        if (savedEmail != null && savedPassword != null) {
          final response = await http
              .post(
                Uri.parse('${ApiConfig.baseUrl}/auth/login'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  "email": savedEmail,
                  "password": savedPassword,
                }),
              )
              .timeout(const Duration(seconds: 10));

          final responseData = jsonDecode(response.body);

          if (response.statusCode == 200) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('token', responseData['token']);
            if (responseData['user'] != null) {
              await prefs.setString(
                  'user_name', responseData['user']['nama'] ?? "User");
              await prefs.setString(
                  'user_email', responseData['user']['email'] ?? savedEmail);
            }
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const MainNavigationScreen()),
            );
          } else {
            if (!mounted) return;
            _showSnack("Sesi bermasalah. Silakan login manual.", isError: true);
          }
        } else {
          if (!mounted) return;
          _showSnack("Belum ada akun tersimpan. Login manual dulu.",
              isError: true);
        }
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error Biometrik: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : _brown700,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Brand Header ─────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _brown900,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: _brown900.withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_cafe_rounded,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Caffio",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: _brown900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Your premium café experience",
                          style: TextStyle(
                            fontSize: 14,
                            color: _brown400,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 44),

                  // ── Card Form ────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: _brown900.withOpacity(0.07),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Welcome back",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _brown900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Sign in to continue",
                          style: TextStyle(
                              fontSize: 14, color: _brown400),
                        ),
                        const SizedBox(height: 28),

                        // Email field
                        _buildLabel("Email"),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _emailController,
                          hint: "you@example.com",
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),

                        // Password field
                        _buildLabel("Password"),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _passwordController,
                          hint: "••••••••",
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                        ),
                        const SizedBox(height: 12),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ForgotPasswordScreen()),
                            ),
                            child: Text(
                              "Forgot password?",
                              style: TextStyle(
                                color: _brown700,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Login button
                        _buildLoginButton(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Register Link ────────────────────────────
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(color: _brown400, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen()),
                          ),
                          child: Text(
                            "Sign Up",
                            style: TextStyle(
                              color: _brown700,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Biometric Section ────────────────────────
                  if (canCheckBiometrics) ...[
                    const SizedBox(height: 36),
                    Row(
                      children: [
                        Expanded(
                            child: Divider(color: _inputBorder, thickness: 1.5)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            "or continue with",
                            style:
                                TextStyle(color: _textHint, fontSize: 12),
                          ),
                        ),
                        Expanded(
                            child: Divider(color: _inputBorder, thickness: 1.5)),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: GestureDetector(
                        onTap: _isLoading ? null : _handleBiometricLogin,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: _isLoading
                                ? _inputBorder
                                : _brown900,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: _isLoading
                                ? []
                                : [
                                    BoxShadow(
                                      color: _brown900.withOpacity(0.30),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                          ),
                          child: Icon(
                            availableBiometrics.contains(BiometricType.face)
                                ? Icons.face_unlock_outlined
                                : Icons.fingerprint_rounded,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        availableBiometrics.contains(BiometricType.face)
                            ? "Face ID"
                            : "Fingerprint",
                        style: TextStyle(
                          color: _brown400,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _brown900,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword ? _obscurePassword : false,
      style: const TextStyle(fontSize: 15, color: _brown900),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textHint, fontSize: 14),
        prefixIcon: Icon(icon, color: _brown400, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _textHint,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        filled: true,
        fillColor: _cream,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _inputBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _inputBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _brown700, width: 2),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: _isLoading
          ? Container(
              decoration: BoxDecoration(
                color: _brown400,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            )
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brown900,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              onPressed: _handleLogin,
              child: const Text(
                "Sign In",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
    );
  }
}