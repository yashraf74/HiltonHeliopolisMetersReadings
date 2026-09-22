import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/api_client.dart';
import '../../state/app_status_controller.dart';

/// Moderator-only page about the app and its developer. The developer's job
/// title comes from the server (KV key `developer_title`), so it can change
/// without an app update and isn't editable from the app.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const AboutScreen()));

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final Future<({String title, String? photoKey})> _about = context
      .read<ApiClient>()
      .fetchAbout();

  static const _gold = Color(0xFFC9A227);

  @override
  Widget build(BuildContext context) {
    final version = context.read<AppStatusController>().appVersion;
    return Scaffold(
      appBar: AppBar(title: Text(S.aboutApp)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _Hero(version: version),
          const SizedBox(height: 16),
          _DeveloperCard(about: _about, gold: _gold),
          const SizedBox(height: 16),
          _Section(
            icon: Icons.work_outline_rounded,
            title: S.experience,
            entries: [
              (S.expHilton, S.expHiltonDates, true),
              (S.expPyramisa, S.expPyramisaDates, false),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            icon: Icons.school_outlined,
            title: S.education,
            entries: [(S.eduDegree, S.eduSchool, false)],
          ),
          const SizedBox(height: 12),
          _Section(
            icon: Icons.workspace_premium_outlined,
            title: S.certifications,
            entries: [(S.certHarvard, S.certHarvardIssued, false)],
          ),
          const SizedBox(height: 16),
          _TextCard(
            icon: Icons.verified_user_outlined,
            title: S.licenseTitle,
            body: S.licenseBody,
          ),
          const SizedBox(height: 12),
          _TextCard(
            icon: Icons.rule_rounded,
            title: S.usageTitle,
            body: S.usageBody,
          ),
          const SizedBox(height: 20),
          _Footer(version: version),
        ],
      ),
    );
  }
}

/// App icon, name, tagline and version on the brand gradient.
class _Hero extends StatelessWidget {
  const _Hero({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accent, Color(0xFF0F1A1E)],
        ),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset('assets/icon/icon.png', width: 84, height: 84),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            S.appName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            S.aboutTagline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${S.version} $version',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Designed and developed by": monogram with a gold ring, name, title from
/// the server, hotel.
class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard({required this.about, required this.gold});

  static const _monogram = Text(
    'KA',
    textDirection: TextDirection.ltr,
    style: TextStyle(
      color: Colors.white,
      fontSize: 26,
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
    ),
  );

  /// Title and photo (of the account named in KV `developer_username`).
  final Future<({String title, String? photoKey})> about;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(
              S.developedBy.toUpperCase(),
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [gold, gold.withValues(alpha: 0.5), gold],
                ),
              ),
              child: FutureBuilder(
                future: about,
                builder: (context, snap) {
                  final key = snap.data?.photoKey;
                  final api = context.read<ApiClient>();
                  return CircleAvatar(
                    radius: 38,
                    backgroundColor: AppColors.accent,
                    foregroundImage: key == null
                        ? null
                        : NetworkImage(
                            api.photoUri(key).toString(),
                            headers: api.authHeaders,
                          ),
                    onForegroundImageError: key == null ? null : (_, _) {},
                    child: _monogram,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              S.developerName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            FutureBuilder(
              future: about,
              builder: (context, snap) {
                final text = snap.data?.title;
                if (text == null || text.isEmpty) {
                  return const SizedBox(height: 20);
                }
                return Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: gold,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.apartment_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    S.hotelName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled list of (title, detail, current) entries with a timeline dot.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.entries,
  });

  final IconData icon;
  final String title;
  final List<(String, String, bool)> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final (heading, detail, current) in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: current
                              ? scheme.primary
                              : scheme.outlineVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            heading,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                          Text(
                            detail,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12);
    return Column(
      children: [
        Text(
          S.copyright,
          textAlign: TextAlign.center,
          style: muted.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(S.trademarkNote, textAlign: TextAlign.center, style: muted),
        TextButton.icon(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: S.appName,
            applicationVersion: version,
            applicationLegalese: S.copyright,
          ),
          icon: const Icon(Icons.description_outlined, size: 18),
          label: Text(S.openSourceLicenses),
        ),
      ],
    );
  }
}
