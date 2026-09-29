// DiceX: DiceX Remote additions — connection regions, invitations and the product link.
//
// Kept in one file so that RustDesk's own files change as little as possible and syncing from
// upstream stays easy. Everything user-facing goes through translate(); the phrases are in
// src/lang/{fa,ar,de}.rs (English is the phrase itself).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// The DiceX Remote landing page.
const String kDiceXRemoteSite = 'https://rs.dicex.me';

/// Languages offered in Settings (owner, 2026-09-29). English is the default
/// (DEFAULT_LOCAL_SETTINGS in libs/hbb_common).
const List<String> kDiceXLanguages = ['en', 'fa', 'ar', 'de'];

class DiceXRegion {
  /// Shown through translate().
  final String label;

  /// ID server and relay (same host).
  final String host;

  /// Invitation service for this region.
  final String api;

  const DiceXRegion(this.label, this.host, this.api);
}

/// Region 1 is the default (DEFAULT_SETTINGS in libs/hbb_common). Every region runs with the same
/// key pair, so switching changes only the host. Two devices can only find each other by ID when
/// they are on the same region: IDs are registered per ID server.
const List<DiceXRegion> kDiceXRegions = [
  DiceXRegion('Region 1', 'rsns01.dicex.me', 'https://rsapi.dicex.me'),
  // DNS outside Iran (Cloudflare), so it keeps resolving if Iran's international link is cut.
  // TODO(dicex): own invitation service once region 2 has its own server.
  DiceXRegion('Region 2', 'rsns02.ntft.tech', 'https://rsapi.dicex.me'),
];

/// The region the app is on, or null for a server the user typed in by hand.
DiceXRegion? diceXCurrentRegion() {
  final configured =
      bind.mainGetOptionSync(key: 'custom-rendezvous-server').trim().toLowerCase();
  if (configured.isEmpty) return kDiceXRegions.first;
  final host = configured.split(':').first;
  for (final region in kDiceXRegions) {
    if (region.host == host) return region;
  }
  return null;
}

/// Same path as Settings > Network > ID/Relay server. The key is left to its default.
Future<void> diceXSetRegion(DiceXRegion region) async {
  await setServerConfig(
      null,
      null,
      ServerConfig(
          idServer: region.host, relayServer: region.host, apiServer: '', key: ''));
}

/// The region next to the ID on the home page; tapping it switches region.
class DiceXRegionChip extends StatefulWidget {
  const DiceXRegionChip({Key? key}) : super(key: key);

  @override
  State<DiceXRegionChip> createState() => _DiceXRegionChipState();
}

class _DiceXRegionChipState extends State<DiceXRegionChip> {
  @override
  Widget build(BuildContext context) {
    final current = diceXCurrentRegion();
    final color =
        Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.6);
    return PopupMenuButton<DiceXRegion>(
      tooltip: translate('Region'),
      padding: EdgeInsets.zero,
      onSelected: (region) async {
        await diceXSetRegion(region);
        if (mounted) setState(() {});
      },
      itemBuilder: (context) => kDiceXRegions
          .map((region) => CheckedPopupMenuItem<DiceXRegion>(
                value: region,
                checked: identical(region, current),
                child: Text(translate(region.label)),
              ))
          .toList(),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.public, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          current == null ? translate('Custom server') : translate(current.label),
          style: TextStyle(fontSize: 12, color: color),
        ),
        Icon(Icons.arrow_drop_down, size: 16, color: color),
      ]),
    );
  }
}

/// Link to the landing page, where upstream showed "Powered by RustDesk".
Widget diceXSiteLink(BuildContext context) {
  return InkWell(
    onTap: () => launchUrl(Uri.parse(kDiceXRemoteSite)),
    child: Opacity(
      opacity: 0.6,
      child: Text(
        translate('DiceX Remote website'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 9, decoration: TextDecoration.underline),
      ),
    ),
  ).marginOnly(top: 6);
}

String _diceXChannelLabel(String channel) {
  switch (channel) {
    case 'sms':
      return 'SMS';
    case 'whatsapp':
      return 'WhatsApp';
    case 'bale':
      return 'Bale';
  }
  return channel;
}

/// The invitation service's error codes, in words.
String _diceXInviteError(String code) {
  switch (code) {
    case 'invalid_mobile':
      return translate(
          "That number doesn't look right. Include the country code, like +96891234567.");
    case 'sms_local_numbers_only':
      return translate('SMS reaches local numbers only. Choose another channel.');
    case 'rate_limited_device':
      return translate('You have reached the invitation limit for now. Try again later.');
    case 'rate_limited_recipient':
      return translate('This number already received an invitation today.');
    case 'rate_limited_network':
      return translate('Too many invitations were sent from your network today.');
    case 'daily_limit_reached':
      return translate('Invitations are paused for today. Try again tomorrow.');
    case 'unknown_id':
    case 'id_not_on_this_network':
      return translate(
          'Wait until your device is connected to the DiceX server, then try again.');
    case 'channel_unavailable':
      return translate("Invitations aren't available on this channel right now.");
    case 'disabled':
      return translate('Invitations are turned off right now.');
  }
  return translate("The invitation couldn't be sent. Try again later.");
}

String _diceXLang() {
  final lang = bind.mainGetLocalOption(key: kCommConfKeyLang);
  return kDiceXLanguages.contains(lang) ? lang : 'en';
}

/// Returns null when sent, otherwise the error in words.
Future<String?> _diceXSendInvite(String api, String mobile, String channel) async {
  try {
    final id = (await bind.mainGetMyId()).replaceAll(' ', '');
    final res = await http
        .post(Uri.parse('$api/v1/invite'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': id,
              'mobile': mobile,
              'channel': channel,
              'lang': _diceXLang(),
            }))
        .timeout(const Duration(seconds: 25));
    final reply = jsonDecode(utf8.decode(res.bodyBytes));
    if (reply is Map && reply['ok'] == true) return null;
    return _diceXInviteError(reply is Map ? '${reply['error'] ?? ''}' : '');
  } catch (_) {
    return _diceXInviteError('');
  }
}

/// "Invite someone": a phone number and a channel; the text is fixed on the server.
Future<void> showDiceXInviteDialog() async {
  final api = (diceXCurrentRegion() ?? kDiceXRegions.first).api;
  var channels = <String>[];
  String? error;
  try {
    final res = await http
        .get(Uri.parse('$api/v1/channels'))
        .timeout(const Duration(seconds: 10));
    final reply = jsonDecode(utf8.decode(res.bodyBytes));
    if (reply is Map && reply['ok'] == true) {
      channels = List<String>.from(reply['channels'] ?? const []);
    } else {
      error = _diceXInviteError('disabled');
    }
  } catch (_) {
    error = _diceXInviteError('');
  }
  if (error == null && channels.isEmpty) {
    error = _diceXInviteError('channel_unavailable');
  }
  final mobile = TextEditingController();
  var channel = channels.isNotEmpty ? channels.first : '';
  var sending = false;

  gFFI.dialogManager.show((setState, close, context) {
    Future<void> submit() async {
      if (sending || channels.isEmpty) return;
      final number = mobile.text.trim();
      if (number.isEmpty) {
        setState(() => error = translate('Enter a mobile number with its country code.'));
        return;
      }
      setState(() {
        sending = true;
        error = null;
      });
      final result = await _diceXSendInvite(api, number, channel);
      if (result == null) {
        close();
        showToast(translate('Invitation sent'));
      } else {
        setState(() {
          sending = false;
          error = result;
        });
      }
    }

    final hint = Theme.of(context).hintColor;
    return CustomAlertDialog(
      title: Text(translate('Invite someone')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(translate('Send someone a link to download DiceX Remote.')),
          const SizedBox(height: 12),
          TextField(
            controller: mobile,
            autofocus: true,
            enabled: !sending,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: translate('Mobile number'),
              hintText: '+96891234567',
            ),
            onSubmitted: (_) => submit(),
          ),
          if (channels.isNotEmpty)
            Row(children: [
              Text(translate('Send via')),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: channel,
                onChanged: sending
                    ? null
                    : (value) => setState(() => channel = value ?? channel),
                items: channels
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text(translate(_diceXChannelLabel(c)))))
                    .toList(),
              ),
            ]).marginOnly(top: 12),
          if (channel == 'sms')
            Text(
              translate('SMS reaches local numbers only. Use WhatsApp for other countries.'),
              style: TextStyle(fontSize: 12, color: hint),
            ).marginOnly(top: 4),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)).marginOnly(top: 10),
          if (sending) const LinearProgressIndicator().marginOnly(top: 10),
        ],
      ),
      actions: [
        dialogButton('Cancel', onPressed: close, isOutline: true),
        dialogButton('Send', onPressed: sending || channels.isEmpty ? null : submit),
      ],
      onSubmit: submit,
      onCancel: close,
    );
  });
}
