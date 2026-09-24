import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/api/api_client.dart';
import '../../data/models.dart';
import '../../state/session_controller.dart';
import '../widgets/photo_picker.dart';

/// Lets the signed-in user set their own photo, email and mobile number,
/// while a moderator keeps that enabled. Roles, usernames and passwords
/// stay with moderators. Values are loaded from the server, so a change a
/// moderator made after this device signed in shows up here.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ProfileScreen()));

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AuthUser _user = context.read<SessionController>().user!;
  // Seeded from the session, then replaced by the server's values.
  late final _email = TextEditingController(text: _user.email ?? '');
  late final _phone = TextEditingController(text: _user.phone ?? '');

  late String? _photoKey = _user.photoKey;
  File? _newPhoto;
  bool _removePhoto = false;
  bool _busy = false;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final me = await context.read<ApiClient>().fetchMe();
      if (!mounted) return;
      _email.text = me.email;
      _phone.text = me.phone ?? '';
      setState(() {
        _photoKey = me.photoKey;
        _loading = false;
      });
      await context.read<SessionController>().updateProfile(
        email: me.email,
        phone: me.phone,
        photoKey: me.photoKey,
      );
    } on NetworkException {
      // Offline: keep what this device knows from sign-in.
      if (mounted) setState(() => _loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isUnauthorized) {
        context.read<SessionController>().markTokenRejected();
      }
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final api = context.read<ApiClient>();
    final session = context.read<SessionController>();
    final messenger = ScaffoldMessenger.of(context);
    final phone = _phone.text.trim();
    try {
      String? uploadedKey;
      if (_newPhoto != null) {
        uploadedKey = await api.uploadPhoto(
          await _newPhoto!.readAsBytes(),
          contentType: contentTypeForPath(_newPhoto!.path),
          forUser: true,
        );
      }
      final saved = await api.saveProfile(
        email: _email.text.trim().toLowerCase(),
        phone: phone.isEmpty ? null : phone,
        clearPhone: phone.isEmpty,
        photoKey: uploadedKey,
        clearPhoto: _removePhoto && uploadedKey == null,
      );
      await session.updateProfile(
        email: saved.email,
        phone: saved.phone,
        photoKey: saved.photoKey,
      );
      if (!mounted) return;
      setState(() {
        _photoKey = saved.photoKey;
        _newPhoto = null;
        _removePhoto = false;
      });
      messenger.showSnackBar(SnackBar(content: Text(S.profileSaved)));
    } on NetworkException {
      messenger.showSnackBar(SnackBar(content: Text(S.onlineRequired)));
    } on ApiException catch (e) {
      if (e.isUnauthorized && mounted) {
        context.read<SessionController>().markTokenRejected();
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (e.code) {
            'profile_editing_disabled' => S.profileEditingDisabled,
            _ when e.message.startsWith('email must') => S.emailInvalid,
            _ when e.message.startsWith('phone must') => S.phoneInvalid,
            _ => e.message,
          }),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final api = context.read<ApiClient>();
    final showStored = _photoKey != null && !_removePhoto && _newPhoto == null;
    final ImageProvider? image = _newPhoto != null
        ? FileImage(_newPhoto!)
        : showStored
        ? NetworkImage(
            api.photoUri(_photoKey!).toString(),
            headers: api.authHeaders,
          )
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(S.myProfile)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  UserPhotoField(
                    enabled: !_busy,
                    image: image,
                    onPicked: (f) => setState(() {
                      _newPhoto = f;
                      _removePhoto = false;
                    }),
                    onRemoved: () => setState(() {
                      _newPhoto = null;
                      _removePhoto = true;
                    }),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _user.fullName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    '${_user.role.label} · @${_user.username}',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    decoration: InputDecoration(
                      labelText: S.email,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return S.fieldRequired;
                      return AppUser.emailPattern.hasMatch(value)
                          ? null
                          : S.emailInvalid;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                    ],
                    decoration: InputDecoration(
                      labelText: S.phone,
                      hintText: S.phoneFormats,
                      helperText: S.phoneOptional,
                      prefixIcon: const Icon(Icons.phone_iphone_rounded),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return null;
                      return AppUser.phonePattern.hasMatch(value)
                          ? null
                          : S.phoneInvalid;
                    },
                  ),
                  if (_loadError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error, fontSize: 12.5),
                    ),
                  ],
                  const SizedBox(height: 24),
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
                        : Text(S.save),
                  ),
                ],
              ),
            ),
    );
  }
}
