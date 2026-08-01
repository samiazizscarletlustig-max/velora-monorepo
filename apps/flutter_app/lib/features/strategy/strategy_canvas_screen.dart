import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      
      if (_isLogin) {
        await repo.signIn(
          email: _emailCtrl.text,
          password: _passCtrl.text,
        );
      } else {
        // تسجيل حساب جديد
        final response = await repo.signUp(
          email: _emailCtrl.text,
          password: _passCtrl.text,
        );
        
        // إذا لم يتم الدخول تلقائياً بعد التسجيل، ندخل يدوياً
        if (response != null && Supabase.instance.client.auth.currentSession == null) {
           await repo.signIn(
            email: _emailCtrl.text,
            password: _passCtrl.text,
          );
        }
      }
      // النجاح يتم التعامل معه تلقائياً عبر goRouter redirect
      
    } on AuthException catch (e) {
      setState(() => _error = _humanize(e.message));
    } catch (e) {
      setState(() => _error = 'حدث خطأ غير متوقع. يرجى المحاولة لاحقاً.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _humanize(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login') || m.contains('invalid credentials')) 
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    if (m.contains('already registered') || m.contains('user already registered')) 
      return 'هذا البريد الإلكتروني مسجل بالفعل.';
    if (m.contains('password')) 
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل.';
    return msg;
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _error = null;
      _confirmCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // الشعار والعنوان
                  Icon(Icons.radar_rounded, size: 64, color: const Color(0xFF34D399)),
                  const SizedBox(height: 16),
                  Text(
                    'Velora',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? 'مرحباً بعودتك' : 'إنشاء حساب جديد',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(fontSize: 16, color: const Color(0xFF8A93A8)),
                  ),
                  const SizedBox(height: 32),

                  // حقل الإيميل
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      labelStyle: const TextStyle(color: Color(0xFF8A93A8)),
                      filled: true,
                      fillColor: const Color(0xFF131A2B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFF8A93A8)),
                    ),
                    validator: (v) => (v == null || !v.contains('@')) ? 'أدخل بريداً إلكترونياً صحيحاً' : null,
                  ),
                  const SizedBox(height: 16),

                  // حقل كلمة المرور
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      labelStyle: const TextStyle(color: Color(0xFF8A93A8)),
                      filled: true,
                      fillColor: const Color(0xFF131A2B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF8A93A8)),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF8A93A8)),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? '6 أحرف على الأقل' : null,
                  ),
                  
                  // تأكيد كلمة المرور (للتسجيل فقط)
                  if (!_isLogin) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: _obscure,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'تأكيد كلمة المرور',
                        labelStyle: const TextStyle(color: Color(0xFF8A93A8)),
                        filled: true,
                        fillColor: const Color(0xFF131A2B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF8A93A8)),
                      ),
                      validator: (v) => v != _passCtrl.text ? 'كلمات المرور غير متطابقة' : null,
                    ),
                  ],

                  // رسالة الخطأ
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFFCA5A5), size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5)))),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // زر الإجراء
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34D399),
                      foregroundColor: const Color(0xFF06281F),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    child: _loading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF06281F)))
                      : Text(_isLogin ? 'تسجيل الدخول' : 'إنشاء حساب'),
                  ),

                  const SizedBox(height: 16),

                  // التبديل بين الدخول والتسجيل
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_isLogin ? 'ليس لديك حساب؟ ' : 'لديك حساب بالفعل؟ ', style: const TextStyle(color: Color(0xFF8A93A8))),
                      GestureDetector(
                        onTap: _loading ? null : _toggleMode,
                        child: Text(_isLogin ? 'إنشاء حساب' : 'تسجيل الدخول', 
                          style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}