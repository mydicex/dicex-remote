// DiceX: when the app opens, ask DiceX's download server whether a newer DiceX Remote is out and,
// if so, offer its download (owner, 2026-10-30). The list is builds.json, the same one the site's
// download page reads, so the app and the site always point at the same file. RustDesk's own
// update check stays off: it is skipped for a custom client and would point at RustDesk.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'version.dart';

const String _kDiceXBuildsUrl = 'https://rsdl.dicex.me/builds.json';
// Each file is published under the first 12 hex digits of its SHA-256 (publish-builds.sh).
const String _kDiceXDownloadBase = 'https://rsdl.dicex.me/b/';
const String _kDiceXSiteUrl = 'https://rs.dicex.me';

Future<void> diceXCheckForUpdate() async {
  final key = _diceXBuildKey();
  if (key == null) return;
  // Let the window (and on Windows the splash) settle first.
  await Future.delayed(const Duration(seconds: 3));
  try {
    final resp = await http
        .get(Uri.parse(_kDiceXBuildsUrl))
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return;
    final data = jsonDecode(resp.body);
    final latest = data['version'];
    if (latest is! String || !diceXIsNewerVersion(latest, kDiceXFullVersion)) {
      return;
    }
    var url = _kDiceXSiteUrl;
    final build = data['builds']?[key];
    if (build is Map && build['file'] is String && build['sha256'] is String) {
      final sha = build['sha256'] as String;
      if (sha.length >= 12) {
        url = '$_kDiceXDownloadBase${sha.substring(0, 12)}/${build['file']}';
      }
    }
    _showDiceXUpdateDialog(latest, url);
  } catch (e) {
    debugPrint('DiceX update check failed: $e');
  }
}

/// The builds.json entry for this device; null where DiceX publishes no build.
String? _diceXBuildKey() {
  if (Platform.isWindows) return 'windows';
  if (Platform.isAndroid) return 'android';
  if (Platform.isMacOS) {
    // Platform.version ends with the OS and CPU, e.g. on "macos_arm64".
    return Platform.version.contains('arm64') ? 'macArm' : 'macIntel';
  }
  return null;
}

/// Whether [latest] is newer than [current], both `<core>-<DiceX version>.<build>`. The DiceX part
/// decides, since it goes up with every build; the core only breaks a tie.
bool diceXIsNewerVersion(String latest, String current) {
  final l = latest.trim().split('-');
  final c = current.trim().split('-');
  if (l.length != 2 || c.length != 2) return false;
  final parts = [l[1], c[1], l[0], c[0]].map(_diceXVersionNumbers).toList();
  if (parts.any((p) => p == null)) return false;
  final dicex = _diceXCompare(parts[0]!, parts[1]!);
  if (dicex != 0) return dicex > 0;
  return _diceXCompare(parts[2]!, parts[3]!) > 0;
}

List<int>? _diceXVersionNumbers(String v) {
  final out = <int>[];
  for (final p in v.split('.')) {
    final n = int.tryParse(p);
    if (n == null) return null;
    out.add(n);
  }
  return out;
}

int _diceXCompare(List<int> a, List<int> b) {
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x < y ? -1 : 1;
  }
  return 0;
}

void _showDiceXUpdateDialog(String latest, String url) {
  gFFI.dialogManager.show((setState, close, context) {
    void download() {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      close();
    }

    return CustomAlertDialog(
      title: Row(children: [
        Icon(Icons.system_update_alt, color: MyTheme.accent),
        const SizedBox(width: 8),
        Flexible(child: Text(translate('Update available'))),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(translate('A new version of DiceX Remote is ready to download.')),
          Text(
            '$kDiceXFullVersion  →  $latest',
            textDirection: TextDirection.ltr,
            style: TextStyle(
                fontSize: 12, color: Theme.of(context).hintColor),
          ).marginOnly(top: 10),
        ],
      ),
      actions: [
        dialogButton('Later', onPressed: close, isOutline: true),
        dialogButton('Download', onPressed: download),
      ],
      onSubmit: download,
      onCancel: close,
    );
  });
}
