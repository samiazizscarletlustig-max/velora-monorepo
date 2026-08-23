import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _loading = false;
  String? _error;

  // ✅ تسجيل الدخول بـ Google فقط (ينشئ الحساب تلقائياً أول مرة)
  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Uri.base.origin,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not open Google sign-in. Please try again.';
        });
      }
    }
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!wide) ...[
                  const _MobileLogo(),
                  const SizedBox(height: 32),
                ],
                Text(
                  'Welcome to Velora',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.05,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Sign in with your Google account to monitor your market in real time.',
                  style: GoogleFonts.manrope(
                    fontSize: 14.5,
                    color: const Color(0xFF8A93A8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                // ✅ زر Google الوحيد — بدون كلمة مرور
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _loading ? null : _signInWithGoogle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Color(0xFF0B1020)),
                                )
                              : const _GoogleLogo(),
                          const SizedBox(width: 12),
                          Text(
                            'Continue with Google',
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0B1020),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: _error == null
                      ? const SizedBox.shrink()
                      : Container(
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

                const SizedBox(height: 24),
                Text(
                  'No password needed. Your Google account keeps you safe.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    color: const Color(0xFF5B657A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// شعار Google
// ═══════════════════════════════════════════════════════
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Color(0xFF4285F4),
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// لوحة الهوية (العمود الأيسر)
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
          Positioned(
            top: -80, left: -60,
            child: _glow(const Color(0xFF10B981), 260),
          ),
          Positioned(
            bottom: -100, right: -80,
            child: _glow(const Color(0xFF22D3EE), 300),
          ),
          const _FloatingShapes(),
          const Positioned.fill(child: _DotGrid()),
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

class _MobileLogo extends StatelessWidget {
  const _MobileLogo();

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