import 'package:flutter/material.dart';
import 'package:personal_tracking_money_project/screens/main_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/database_users.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoginTab = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      _showMessage('Vui lòng nhập đầy đủ tài khoản và mật khẩu!');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final isValid = await DatabaseUsers.instance.checkLogin(
        username,
        password,
      );
      if (isValid) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('currentUsername', username);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const MainDashboardScreen(),
            ),
          );
        }
      } else {
        _showMessage('Tài khoản hoặc mật khẩu không chính xác!');
      }
    } catch (e) {
      _showMessage('Lỗi hệ thống database: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    if (username.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Vui lòng nhập đầy đủ các thông tin!');
      return;
    }
    if (password != confirmPassword) {
      _showMessage('Mật khẩu nhập lại không trùng khớp!');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await DatabaseUsers.instance.registerUser(
        username,
        password,
      );
      if (result != -1) {
        _showMessage('Đăng ký thành công! Hãy đăng nhập.', isSuccess: true);
        setState(() {
          _passwordController.clear();
          _confirmPasswordController.clear();
          _isLoginTab = true;
        });
      } else {
        _showMessage('Tên tài khoản này đã tồn tại!');
      }
    } catch (e) {
      _showMessage('Lỗi khi đăng ký: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      //  Đổi nền màn hình
      backgroundColor: isDark
          ? const Color(0xFF111827)
          : const Color(0xFFF8F9FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.savings_outlined,
                size: 80,
                color: isDark ? Colors.blueAccent : Colors.blue,
              ),
              const SizedBox(height: 12),
              Text(
                'SAVINGS TRACKER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.blueAccent : Colors.blue,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLoginTab
                    ? 'Quản lý tài chính thông minh'
                    : 'Tạo tài khoản tiết kiệm mới',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey,
                ),
              ),
              const SizedBox(height: 32),

              _buildTextField(
                _usernameController,
                'Tên đăng nhập',
                Icons.person_outline,
                isDark,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _passwordController,
                'Mật khẩu',
                Icons.lock_outline,
                isDark,
                obscure: true,
              ),
              const SizedBox(height: 16),

              if (!_isLoginTab) ...[
                _buildTextField(
                  _confirmPasswordController,
                  'Xác nhận mật khẩu',
                  Icons.lock_reset_outlined,
                  isDark,
                  obscure: true,
                ),
                const SizedBox(height: 24),
              ] else
                const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : (_isLoginTab ? _handleLogin : _handleRegister),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.blueAccent : Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isLoginTab ? 'ĐĂNG NHẬP' : 'ĐĂNG KÝ NGAY',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLoginTab ? 'Chưa có tài khoản? ' : 'Đã có tài khoản? ',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.black54,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isLoginTab = !_isLoginTab;
                        _usernameController.clear();
                        _passwordController.clear();
                        _confirmPasswordController.clear();
                      });
                    },
                    child: Text(
                      _isLoginTab ? 'Đăng ký' : 'Đăng nhập',
                      style: TextStyle(
                        color: isDark ? Colors.blueAccent : Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  //  Widget TextField tiện ích để đổi màu nền
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool isDark, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.grey.shade400 : Colors.grey,
        ),
        prefixIcon: Icon(icon, color: isDark ? Colors.blueAccent : Colors.blue),
        filled: true,
        fillColor: isDark ? const Color(0xFF374151) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
