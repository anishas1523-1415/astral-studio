// Astral Studio update banner (master copy: Astral Studio repo, sdk/flutter/astral_update.dart).
//
// On each launch the app compares its own version with the newest one listed for it on
// Astral Studio (apps.json) and, if it is behind, shows a card with an Update button that opens
// the app's Astral Studio page, where the new APK downloads.
//
// Use: MaterialApp(builder: (context, child) => AstralUpdateBanner(appId: 'my-app', child: child!), ...)
// Needs package_info_plus and url_launcher.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const _catalogUrl = 'https://astral-studio.web.app/apps.json';

class AstralUpdateBanner extends StatefulWidget {
  const AstralUpdateBanner({super.key, required this.appId, required this.child});

  /// The app's id on Astral Studio (the <id> in astral-studio.web.app/get/<id>)
  final String appId;
  final Widget child;

  @override
  State<AstralUpdateBanner> createState() => _AstralUpdateBannerState();
}

class _AstralUpdateBannerState extends State<AstralUpdateBanner> {
  Map<String, dynamic>? _latest;
  String _installed = '';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(_catalogUrl));
      final response = await request.close();
      if (response.statusCode != 200) return;
      final catalog = jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
      client.close();
      final app = (catalog['apps'] as List).cast<Map<String, dynamic>>().where((a) => a['id'] == widget.appId);
      if (app.isEmpty) return;
      final versions = (app.first['versions'] as List).cast<Map<String, dynamic>>();
      if (versions.isEmpty || !_isNewer('${versions.first['version']}', info.version)) return;
      if (mounted) setState(() { _latest = versions.first; _installed = info.version; });
    } catch (_) {
      // Offline or the store is unreachable: try again next launch
    }
  }

  // "1.0.10" > "1.0.9": compare each dot-separated part as a number
  static bool _isNewer(String latest, String installed) {
    final a = latest.split('.').map((n) => int.tryParse(n) ?? 0).toList();
    final b = installed.split('.').map((n) => int.tryParse(n) ?? 0).toList();
    for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
      final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  void _later() => setState(() => _latest = null); // shows again next time the app opens

  Future<void> _update() async {
    final page = Uri.parse('https://astral-studio.web.app/app.html?id=${widget.appId}');
    await launchUrl(page, mode: LaunchMode.externalApplication);
    _later();
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latest;
    return Stack(
      children: [
        widget.child,
        if (latest != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            child: Material(
              color: const Color(0xF0141028),
              elevation: 12,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x5900FFCC)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.system_update, color: Color(0xFF00FFCC), size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Version ${latest['version']} is available',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.5)),
                          Text('You have $_installed${latest['size'] != null ? ' · ${latest['size']} download' : ''}',
                              style: const TextStyle(color: Colors.white60, fontSize: 12)),
                        ]),
                      ),
                    ]),
                    if ((latest['notes'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('${latest['notes']}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35)),
                    ],
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _later,
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
                          child: const Text('Later'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _update,
                          style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF00FFCC), foregroundColor: const Color(0xFF0B0B14)),
                          child: const Text('Update', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
