import 'dart:math' as math;
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

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  late final AnimationController _floatCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _floatCtrl.dispose();
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
        final user = await repo.signUp(
          email: _emailCtrl.text,
          password: _passCtrl.text,
        );
        // احتياط: إن لم تُنشأ جلسة تلقائياً، نسجّل الدخول صراحة.
        if (user != null && Supabase.instance.client.auth.currentSession == null) {
          await repo.signIn(
            email: _emailCtrl.text,
            password: _passCtrl.text,
          );
        }
      }
      // عند النجاح: البثّ + الـ router يتولّيان التوجيه — لا نفعل شيئاً هنا.
    } on AuthException catch (e) {
      setState(() => _error = _humanize(e.message));
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _humanize(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login')) return 'Wrong email or password.';
    if (m.contains('already registered')) return 'This email already has an account.';
    if (m.contains('password') && m.contains('least')) return 'Password must be at least 6 characters.';
    if (m.contains('rate limit')) return 'Too many attempts. Wait a moment.';
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 920;
          if (wide) {
            return Row(
              children: [
                const Expanded(flex: 5, child: _BrandPanel()),
                Expanded(flex: 6, child: _buildForm(wide: true)),
              ],
            );
          }
          return _buildForm(wide: false);
        },
      ),
    );
  }

  Widget _buildForm({required bool wide}) {
    return Container(
      color: const Color(0xFF0E1424),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 48 : 28,
              vertical: 40,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!wide) ...[
                    _MobileLogo(),
                    const SizedBox(height: 32),
                  ],
                  // ── عنوان بتباين قوي ──
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    child: Text(
                      _isLogin ? 'Welcome back' : 'Create account',
                      key: ValueKey(_isLogin),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.05,
                        letterSpacing: -1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isLogin
                        ? 'Sign in to monitor your market in real time.'
                        : 'Start tracking competitors in under a minute.',
                    style: GoogleFonts.manrope(
                      fontSize: 14.5,
                      color: const Color(0xFF8A93A8),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 34),

                  // ── Email ──
                  _Field(
                    controller: _emailCtrl,
                    label: 'Email',
                    hint: 'you@company.com',
                    icon: Icons.mail_outline_rounded,
                    keyboard: TextInputType.emailAddress,
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 18),

                  // ── Password ──
                  _Field(
                    controller: _passCtrl,
                    label: 'Password',
                    hint: '••••••••',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscure,
                    toggleObscure: () => setState(() => _obscure = !_obscure),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'At least 6 characters' : null,
                  ),

                  // ── Confirm (signup فقط) ─
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _isLogin
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: _Field(
                              controller: _confirmCtrl,
                              label: 'Confirm password',
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscure,
                              validator: (v) => v != _passCtrl.text
                                  ? 'Passwords do not match'
                                  : null,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),

                  // ── رسالة الخطأ ──
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    child: _error == null
                        ? const SizedBox.shrink()
                        : Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFFEF4444).withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 18, color: Color(0xFFFCA5A5)),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: GoogleFonts.manrope(
                                        fontSize: 13, color: const Color(0xFFFCA5A5)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 14),

                  // ── زر الإجراء بتغذية راجعة ──
                  _SubmitButton(
                    loading: _loading,
                    label: _isLogin ? 'Sign in' : 'Create account',
                    onTap: _loading ? null : _submit,
                  ),
                  const SizedBox(height: 22),

                  // ── تبديل الوضع ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? 'No account yet? ' : 'Already have one? ',
                        style: GoogleFonts.manrope(
                            fontSize: 13.5, color: const Color(0xFF8A93A8)),
                      ),
                      GestureDetector(
                        onTap: _loading ? null : _toggleMode,
                        child: Text(
                          _isLogin ? 'Sign up' : 'Sign in',
                          style: GoogleFonts.manrope(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF34D399),
                          ),
                        ),
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

// ═══════════════════════════════════════════════════════
// لوحة الهوية الحيّة (العمود الأيسر)
// ═══════════════════════════════════════════════════════

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B1020),
        gradient: RadialGradient(
          center: Alignment(-0.6, -0.7),
          radius: 1.3,
          colors: [Color(0xFF11203A), Color(0xFF0B1020)],
        ),
      ),
      child: Stack(
        children: [
          // توهّجات خافتة
          Positioned(
            top: -80, left: -60,
            child: _glow(const Color(0xFF10B981), 260),
          ),
          Positioned(
            bottom: -100, right: -80,
            child: _glow(const Color(0xFF22D3EE), 300),
          ),
          // عناصر طافية حيّة
          const _FloatingShapes(),
          // شبكة نقاط خافتة
          const Positioned.fill(child: _DotGrid()),
          // المحتوى
          Padding(
            padding: const EdgeInsets.all(56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF22D3EE)],
                        ),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.radar_rounded,
                          color: Color(0xFF06281F), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Velora',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 44),
                Text(
                  'Competitive\nintelligence that\nthinks with you.',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.08,
                    letterSpacing: -1.4,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Track prices, catch moves, and turn competitor data into strategy — automatically.',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    color: const Color(0xFF9AA4BA),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 40),
                const _ValueRow(icon: Icons.bolt_rounded, text: 'Real-time price tracking'),
                const SizedBox(height: 14),
                const _ValueRow(icon: Icons.psychology_rounded, text: 'AI-generated insights'),
                const SizedBox(height: 14),
                const _ValueRow(icon: Icons.lock_outline_rounded, text: 'Your data stays yours'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(Color color, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.22), color.withOpacity(0.0)],
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ValueRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF34D399)),
        const SizedBox(width: 12),
        Text(
          text,
          style: GoogleFonts.manrope(
            fontSize: 14.5,
            color: const Color(0xFFD4DAE6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// العناصر الطافية (حركة عضوية مستقلة)
// ═══════════════════════════════════════════════════════

// ⚠️ تنبيه: إذا وجدت تعريفاً آخر لـ _FloatingShapes أعلى في الملف
// (يبدأ بـ class _FloatingShapes extends StatelessWidget)، احذفه بالكامل
// واترك هذا التعريف فقط. وجودهما معاً يسبب خطأ duplicate definition.
class _FloatingShapes extends StatefulWidget {
  const _FloatingShapes();
  @override
  State<_FloatingShapes> createState() => _FloatingShapesState();
}

class _FloatingShapesState extends State<_FloatingShapes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 2 * math.pi;
        return Stack(
          children: [
            _orb(t, 0.0, 0.18, 0.78, 90, const Color(0xFF10B981)),
            _orb(t, 1.7, 0.62, 0.30, 60, const Color(0xFF22D3EE)),
            _orb(t, 3.1, 0.30, 0.62, 44, const Color(0xFF34D399)),
            _ring(t, 2.2, 0.74, 0.70, 120),
          ],
        );
      },
    );
  }

  Widget _orb(double t, double phase, double xRatio, double yRatio,
      double size, Color color) {
    final dx = math.sin(t + phase) * 18;
    final dy = math.cos(t * 0.8 + phase) * 22;
    return Positioned(
      left: xRatio * 1000 + dx,
      top: yRatio * 800 + dy,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.25), width: 1.4),
        ),
      ),
    );
  }

  Widget _ring(double t, double phase, double xRatio, double yRatio, double size) {
    final dy = math.sin(t * 0.6 + phase) * 26;
    return Positioned(
      left: xRatio * 1000,
      top: yRatio * 800 + dy,
      child: Transform.rotate(
        angle: t * 0.3,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF22D3EE).withOpacity(0.18), width: 1.2),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// شعار للموبايل
// ═══════════════════════════════════════════════════════

class _MobileLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF22D3EE)]),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.radar_rounded,
              color: Color(0xFF06281F), size: 20),
        ),
        const SizedBox(width: 11),
        Text('Velora',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// الحقل
// ═══════════════════════════════════════════════════════

class _Field extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboard;
  final bool obscure;
  final VoidCallback? toggleObscure;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboard,
    this.obscure = false,
    this.toggleObscure,
    this.validator,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final border = _focused
        ? const Color(0xFF34D399)
        : const Color(0xFF2A3346);
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label,
              style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF9AA4BA),
                  letterSpacing: 0.3)),
          const SizedBox(height: 7),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: const Color(0xFF131A2B),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: border, width: _focused ? 1.6 : 1.2),
            ),
            child: TextFormField(
              controller: widget.controller,
              keyboardType: widget.keyboard,
              obscureText: widget.obscure,
              style: GoogleFonts.manrope(fontSize: 15, color: Colors.white),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: GoogleFonts.manrope(
                    fontSize: 15, color: const Color(0xFF4B5568)),
                prefixIcon: Icon(widget.icon,
                    size: 19,
                    color: _focused
                        ? const Color(0xFF34D399)
                        : const Color(0xFF5B657A)),
                suffixIcon: widget.toggleObscure != null
                    ? IconButton(
                        icon: Icon(
                          widget.obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 19,
                          color: const Color(0xFF5B657A),
                        ),
                        onPressed: widget.toggleObscure,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 15),
              ),
              validator: widget.validator,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// زر الإجراء
// ═══════════════════════════════════════════════════════

class _SubmitButton extends StatefulWidget {
  final bool loading;
  final String label;
  final VoidCallback? onTap;
  const _SubmitButton({
    required this.loading,
    required this.label,
    required this.onTap,
  });

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover && !widget.loading ? 1.012 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 54,
            decoration: BoxDecoration(
              gradient: widget.loading
                  ? const LinearGradient(colors: [
                      Color(0xFF0E7A5B),
                      Color(0xFF0E7A5B),
                    ])
                  : const LinearGradient(colors: [
                      Color(0xFF10B981),
                      Color(0xFF22D3EE),
                    ]),
              borderRadius: BorderRadius.circular(13),
              boxShadow: _hover && !widget.loading
                  ? [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.35),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      )
                    ]
                  : [],
            ),
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Color(0xFF06281F)),
                    )
                  : Text(
                      widget.label,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF06281F),
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// شبكة النقاط الخافتة
// ══════════════════════════════════════════════════════

class _DotGrid extends StatelessWidget {
  const _DotGrid();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DotPainter());
  }
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFFFFF).withOpacity(0.04);
    const gap = 26.0;
    for (double x = 0; x < size.width; x += gap) {
      for (double y = 0; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}