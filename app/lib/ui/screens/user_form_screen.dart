import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/api/api_client.dart';
import '../../data/models.dart';
import '../../state/session_controller.dart';

/// Create a user, or edit name / role / active flag and reset the password
/// of an existing one. Pops with `true` when something was saved.
class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key, this.existing});

  final AppUser? existing;

  static Future<bool?> open(BuildContext context, {AppUser? existing}) =>
      Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => UserFormScreen(existing: existing)),
      );

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  static final _usernameRe = RegExp(r'^[a-z0-9_.]{3,32}$');

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username;
  late final TextEditingController _fullName;
  final _password = TextEditingController();
  late UserRole _role;
  late bool _isActive;
  bool _obscure = true;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;
  bool get _isSelf =>
      widget.existing?.id == context.read<SessionController>().user?.id;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.existing?.username ?? '');
    _fullName = TextEditingController(text: widget.existing?.fullName ?? '');
    _role = widget.existing?.role ?? UserRole.technician;
    _isActive = widget.existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _username.dispose();
    _fullName.dispose();
    _password.dispose();
    super.dispose();
  }

  String _arabicError(ApiException e) {
    if (e.statusCode == 409) return S.usernameTaken;
    if (e.message.startsWith('username must')) return S.usernameRules;
    if (e.message.startsWith('password must')) return S.passwordRules;
    if (e.message.startsWith('You cannot deactivate')) return S.cannotEditSelf;
    return e.message;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final api = context.read<ApiClient>();
    final messenger = ScaffoldMessenger.of(context);
    final password = _password.text;
    try {
      if (_isEdit) {
        await api.updateUser(
          widget.existing!.id,
          fullName: _fullName.text.trim(),
          role: _role,
          isActive: _isActive,
          password: password.isEmpty ? null : password,
        );
      } else {
        await api.createUser(
          username: _username.text.trim().toLowerCase(),
          password: password,
          fullName: _fullName.text.trim(),
          role: _role,
        );
      }
      messenger.showSnackBar(const SnackBar(content: Text(S.userSaved)));
      if (mounted) Navigator.of(context).pop(true);
    } on NetworkException {
      messenger.showSnackBar(
        const SnackBar(content: Text(S.usersNeedInternet)),
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized && mounted) {
        context.read<SessionController>().markTokenRejected();
      }
      messenger.showSnackBar(SnackBar(content: Text(_arabicError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? S.editUser : S.addUser)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _username,
              enabled: !_isEdit,
              textDirection: TextDirection.ltr,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')),
              ],
              decoration: const InputDecoration(
                labelText: S.username,
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (v) =>
                  _usernameRe.hasMatch((v ?? '').trim().toLowerCase())
                  ? null
                  : S.usernameRules,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _fullName,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: S.fullName,
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? S.fieldRequired : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: _isEdit ? S.newPassword : S.password,
                helperText: _isEdit ? S.resetPasswordHint : S.passwordRules,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                final value = v ?? '';
                if (_isEdit && value.isEmpty) return null;
                return value.length < 6 ? S.passwordRules : null;
              },
            ),
            const SizedBox(height: 20),
            Text(S.role, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final r in UserRole.values)
                  ChoiceChip(
                    label: Text(r.label),
                    avatar: Icon(
                      r == UserRole.engineer
                          ? Icons.engineering_rounded
                          : Icons.build_rounded,
                      size: 18,
                    ),
                    selected: _role == r,
                    onSelected: _busy || _isSelf
                        ? null
                        : (_) => setState(() => _role = r),
                  ),
              ],
            ),
            if (_isEdit) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  S.accountActive,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  _isSelf ? S.cannotEditSelf : S.accountActiveHint,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
                value: _isActive,
                onChanged: _busy || _isSelf
                    ? null
                    : (v) => setState(() => _isActive = v),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(S.save),
            ),
          ],
        ),
      ),
    );
  }
}
