import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../data/api/api_client.dart';
import '../state/app_status_controller.dart';
import '../state/connectivity_controller.dart';
import '../state/session_controller.dart';
import 'widgets/status_widgets.dart';

/// Full-bleed hotel photo fading into the ink ground, the gauge badge, and
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
    final error = await session.signIn(api, username, password);
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
          // Full-screen photo raised by 20% of the screen height; the bottom
          // 20% it leaves behind is plain black.
          Positioned(
            top: -height * 0.2,
            left: 0,
            right: 0,
            height: height,
            child: Image.asset(
              'assets/images/login_bg.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: height * 0.2,
            child: const ColoredBox(color: Colors.black),
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
                        const Text(
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
                        const Text(
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
                              : const Text(S.loginButton),
                        ),
                        if (!isOnline) ...[
                          const SizedBox(height: 18),
                          const Row(
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
        ],
      ),
    );
  }
}
