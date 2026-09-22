import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../data/api/api_client.dart';
import '../state/app_status_controller.dart';
import '../state/connectivity_controller.dart';
import '../state/language_controller.dart';
import '../state/session_controller.dart';
import 'widgets/status_widgets.dart';

/// Hotel photo wallpaper (see [_Wallpaper]), the gauge badge, and
/// translucent fields — per the design reference.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  static const _fieldFill = Color(0x66142229);
  static const _fieldBorder = Color(0x80FFFFFF);

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = S.loginRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = context.read<SessionController>();
    final api = context.read<ApiClient>();
    final status = context.read<AppStatusController>();
    final language = context.read<LanguageController>();
    final error = await session.signIn(
      api,
      username,
      password,
      beforeSignedIn: (user) => language.signedIn(user),
    );
    if (!mounted) return;
    if (error == null) {
      status.refresh(api, isModerator: session.user?.canManage ?? false);
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        floatingLabelStyle: const TextStyle(color: Colors.white),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: suffix,
        filled: true,
        fillColor: _fieldFill,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.white, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 20,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityController>().isOnline;
    final height = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Sized to the whole screen so it stays put when the keyboard
          // shrinks the body.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: height,
            child: const _Wallpaper(),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: height * 0.36),
                        Center(
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x66000000),
                                  blurRadius: 20,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.speed_rounded,
                              color: Colors.white,
                              size: 46,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          S.appName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          S.login,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                        const SizedBox(height: 28),
                        TextField(
                          controller: _username,
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: Colors.white,
                          contextMenuBuilder: appContextMenuBuilder,
                          decoration: _decoration(
                            S.username,
                            Icons.person_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _busy ? null : _submit(),
                          style: const TextStyle(color: Colors.white),
                          cursorColor: Colors.white,
                          contextMenuBuilder: appContextMenuBuilder,
                          decoration: _decoration(
                            S.password,
                            Icons.lock_outline_rounded,
                            suffix: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                color: Colors.white70,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFB4AB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            minimumSize: const Size.fromHeight(58),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(S.loginButton),
                        ),
                        if (!isOnline) ...[
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.wifi_off_rounded,
                                size: 18,
                                color: Colors.white54,
                              ),
                              SizedBox(width: 6),
                              Text(
                                S.offline,
                                style: TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Language toggle: last in the stack so it sits above the form.
          // Remembered on this device; after sign-in the account's saved
          // language takes over.
          PositionedDirectional(
            top: 0,
            end: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => context.read<LanguageController>().choose(
                    S.isEnglish ? AppLanguage.ar : AppLanguage.en,
                  ),
                  icon: const Icon(Icons.translate_rounded, size: 18),
                  label: Text(S.switchLanguage),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The login photo, shown whole and centred at its own proportions. When the
/// screen's shape differs from the photo's, the spare space is filled by
/// stretching the photo's edge strips outward and blurring them, and the
/// photo's edges on those sides fade into that, so the sky carries on above,
/// the ground below, and the scene to either side.
class _Wallpaper extends StatefulWidget {
  const _Wallpaper();

  @override
  State<_Wallpaper> createState() => _WallpaperState();
}

class _WallpaperState extends State<_Wallpaper> {
  static const _asset = AssetImage('assets/images/login_bg.jpg');

  ImageStream? _stream;
  ImageInfo? _info;
  late final _listener = ImageStreamListener((info, _) {
    if (!mounted) return info.dispose();
    setState(() {
      _info?.dispose();
      _info = info;
    });
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = _asset.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _info?.image;
    if (image == null) return const SizedBox.shrink();
    final screen = MediaQuery.sizeOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: 30,
            sigmaY: 30,
            tileMode: TileMode.clamp,
          ),
          child: CustomPaint(painter: _StretchedEdgesPainter(image)),
        ),
        FittedBox(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (photo) => _edgeFade(photo, screen),
            child: RawImage(image: image),
          ),
        ),
      ],
    );
  }

  /// [photo] is in the photo's own pixels; the fade is sized on screen.
  static Shader _edgeFade(Rect photo, Size screen) {
    final scale = min(screen.width / photo.width, screen.height / photo.height);
    final spareX = screen.width - photo.width * scale;
    final spareY = screen.height - photo.height * scale;
    final vertical = spareY > spareX;
    final spare = vertical ? spareY : spareX;
    if (spare < 1) {
      return const LinearGradient(colors: [Colors.white, Colors.white])
          .createShader(photo);
    }
    final length = (vertical ? photo.height : photo.width) * scale;
    final fade = min(max(spare, 32.0), length * 0.18) / length;
    return LinearGradient(
      begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
      end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
      colors: const [
        Colors.transparent,
        Colors.white,
        Colors.white,
        Colors.transparent,
      ],
      stops: [0, fade, 1 - fade, 1],
    ).createShader(photo);
  }
}

/// Paints the photo centred (contain) with a thin strip from each edge
/// stretched across the spare space beside it.
class _StretchedEdgesPainter extends CustomPainter {
  _StretchedEdgesPainter(this.image);

  final ui.Image image;

  /// Fraction of the photo taken as the strip to stretch.
  static const _strip = 0.02;

  @override
  void paint(Canvas canvas, Size size) {
    final src =
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(BoxFit.contain, src.size, size).destination;
    final photo = Alignment.center.inscribe(fitted, Offset.zero & size);
    final paint = Paint()..filterQuality = FilterQuality.low;
    canvas.drawImageRect(image, src, photo, paint);

    final sw = src.width * _strip;
    final sh = src.height * _strip;
    if (photo.left > 0) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, sw, src.height),
        Rect.fromLTRB(0, photo.top, photo.left, photo.bottom),
        paint,
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(src.width - sw, 0, sw, src.height),
        Rect.fromLTRB(photo.right, photo.top, size.width, photo.bottom),
        paint,
      );
    }
    if (photo.top > 0) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, src.width, sh),
        Rect.fromLTRB(photo.left, 0, photo.right, photo.top),
        paint,
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, src.height - sh, src.width, sh),
        Rect.fromLTRB(photo.left, photo.bottom, photo.right, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StretchedEdgesPainter old) => old.image != image;
}
