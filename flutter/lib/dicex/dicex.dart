// DiceX: DiceX Remote additions — connection regions, invitations, the language flags and the
// product link.
//
// Kept in one file so that RustDesk's own files change as little as possible and syncing from
// upstream stays easy. Everything user-facing goes through translate(); the phrases are in
// src/lang/{fa,ar,de}.rs (English is the phrase itself). Artwork is in assets/dicex/.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// The DiceX Remote landing page.
const String kDiceXRemoteSite = 'https://rs.dicex.me';

/// Languages offered in Settings (owner, 2026-09-29). English is the default
/// (DEFAULT_LOCAL_SETTINGS in libs/hbb_common).
const List<String> kDiceXLanguages = ['en', 'fa', 'ar', 'de'];

class DiceXLanguage {
  final String code;

  /// File name part of assets/dicex/flag_<flag>.svg (flag-icons, MIT, see FLAGS-LICENSE.txt).
  final String flag;

  /// The language's own name, shown as the flag's tooltip.
  final String name;

  const DiceXLanguage(this.code, this.flag, this.name);
}

/// The flags on the home page (owner, 2026-10-01), in the order of [kDiceXLanguages].
const List<DiceXLanguage> kDiceXLanguageFlags = [
  DiceXLanguage('en', 'gb', 'English'),
  DiceXLanguage('fa', 'ir', 'فارسی'),
  DiceXLanguage('ar', 'om', 'العربية'),
  DiceXLanguage('de', 'de', 'Deutsch'),
];

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

String _diceXLang() {
  final lang = bind.mainGetLocalOption(key: kCommConfKeyLang);
  return kDiceXLanguages.contains(lang) ? lang : 'en';
}

/// Same steps as the language box in Settings.
Future<void> diceXSetLanguage(String lang) async {
  await bind.mainSetLocalOption(key: kCommConfKeyLang, value: lang);
  reloadAllWindows();
  bind.mainChangeLanguage(lang: lang);
}

/// The language flags at the bottom of the home page's left pane, besides the box in Settings.
class DiceXLanguageFlags extends StatelessWidget {
  const DiceXLanguageFlags({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isOptionFixed(kCommConfKeyLang)) return const SizedBox.shrink();
    final current = _diceXLang();
    final border = Theme.of(context).dividerColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: kDiceXLanguageFlags.map((language) {
        final selected = language.code == current;
        return Tooltip(
          message: language.name,
          child: Semantics(
            button: true,
            selected: selected,
            label: language.name,
            child: InkWell(
              onTap: selected ? null : () => diceXSetLanguage(language.code),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: selected ? MyTheme.accent : Colors.transparent,
                      width: 1.5),
                ),
                child: Opacity(
                  opacity: selected ? 1 : 0.6,
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: border, width: 0.5)),
                    child: SvgPicture.asset(
                      'assets/dicex/flag_${language.flag}.svg',
                      width: 24,
                      height: 18,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ).marginOnly(right: 4);
      }).toList(),
    );
  }
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

/// The same channel marks as DiceX Connect (dicex-connect/assets/images/channels).
Widget _diceXChannelIcon(String channel, {double size = 18}) {
  switch (channel) {
    case 'sms':
    case 'whatsapp':
      return SvgPicture.asset('assets/dicex/channel_$channel.svg',
          width: size, height: size);
    case 'bale':
      return Image.asset('assets/dicex/channel_bale.png',
          width: size, height: size, filterQuality: FilterQuality.medium);
  }
  return Icon(Icons.chat_bubble_outline, size: size);
}

/// One channel to choose. Not a DropdownButton: its menu is a route on the window's navigator,
/// which sits below RustDesk's dialog overlay, so the menu opened behind the dialog.
Widget _diceXChannelOption(BuildContext context, String channel, bool selected,
    VoidCallback? onTap) {
  return Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected ? MyTheme.accent.withOpacity(0.12) : null,
          border: Border.all(
            color: selected ? MyTheme.accent : Theme.of(context).dividerColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _diceXChannelIcon(channel),
          const SizedBox(width: 6),
          Text(translate(_diceXChannelLabel(channel))),
        ]),
      ),
    ),
  );
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
      return translate("You've used today's messages. You can send more tomorrow.");
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

class _DiceXInviteOptions {
  var channels = <String>[];

  /// Today's messages for this device: both kinds count (server LIMIT_PER_ID_DAY).
  int? limit;
  int? remaining;
  String? error;
}

Future<_DiceXInviteOptions> _diceXInviteOptions(String api, String id) async {
  final options = _DiceXInviteOptions();
  try {
    final res = await http
        .get(Uri.parse('$api/v1/channels').replace(queryParameters: {'id': id}))
        .timeout(const Duration(seconds: 10));
    final reply = jsonDecode(utf8.decode(res.bodyBytes));
    if (reply is Map && reply['ok'] == true) {
      options.channels = List<String>.from(reply['channels'] ?? const []);
      final quota = reply['quota'];
      if (quota is Map) {
        options.limit = (quota['limit'] as num?)?.toInt();
        options.remaining = (quota['remaining'] as num?)?.toInt();
      }
    } else {
      options.error = _diceXInviteError('disabled');
    }
  } catch (_) {
    options.error = _diceXInviteError('');
  }
  if (options.error == null && options.channels.isEmpty) {
    options.error = _diceXInviteError('channel_unavailable');
  }
  return options;
}

/// Returns null when sent, otherwise the error in words.
Future<String?> _diceXSendInvite(
    String api, String id, String mobile, String channel, bool shareId) async {
  try {
    final res = await http
        .post(Uri.parse('$api/v1/invite'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': id,
              'mobile': mobile,
              'channel': channel,
              'lang': _diceXLang(),
              'kind': shareId ? 'share_id' : 'invite',
            }))
        .timeout(const Duration(seconds: 25));
    final reply = jsonDecode(utf8.decode(res.bodyBytes));
    if (reply is Map && reply['ok'] == true) return null;
    return _diceXInviteError(reply is Map ? '${reply['error'] ?? ''}' : '');
  } catch (_) {
    return _diceXInviteError('');
  }
}

/// "Invite someone" sends a link to download DiceX Remote; with [shareId] ("Send my ID") the
/// message also carries this device's ID, so the recipient can connect to it. Only a number and
/// a channel come from here: the server writes the text and inserts the ID it has verified. The
/// password is never sent.
Future<void> showDiceXInviteDialog({bool shareId = false}) async {
  final api = (diceXCurrentRegion() ?? kDiceXRegions.first).api;
  final id = (await bind.mainGetMyId()).replaceAll(' ', '');
  final mobile = TextEditingController();
  var loading = true;
  var channels = <String>[];
  var channel = '';
  int? limit;
  int? remaining;
  String? error;
  var sending = false;
  var closed = false;
  StateSetter? update;

  // Opens at once and fills in when the service answers, instead of waiting for it.
  gFFI.dialogManager.show((setState, close, context) {
    update = setState;
    void dismiss() {
      closed = true;
      close();
    }

    final usedUp = remaining != null && remaining! <= 0;
    final canSend = !loading && !sending && !usedUp && channels.isNotEmpty;

    Future<void> submit() async {
      if (!canSend) return;
      final number = mobile.text.trim();
      if (number.isEmpty) {
        setState(() => error = translate('Enter a mobile number with its country code.'));
        return;
      }
      setState(() {
        sending = true;
        error = null;
      });
      final result = await _diceXSendInvite(api, id, number, channel, shareId);
      if (closed) return;
      if (result == null) {
        dismiss();
        showToast(translate(shareId ? 'Your ID was sent' : 'Invitation sent'));
      } else {
        setState(() {
          sending = false;
          error = result;
        });
      }
    }

    final hint = Theme.of(context).hintColor;
    return CustomAlertDialog(
      title: Text(translate(shareId ? 'Send my ID' : 'Invite someone')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(translate(shareId
              ? 'Send someone your ID and a link to download DiceX Remote, so they can connect to this computer.'
              : 'Send someone a link to download DiceX Remote.')),
          if (shareId && !usedUp)
            Text(
              translate('Your password is not sent. Tell it to them yourself when they connect.'),
              style: TextStyle(fontSize: 12, color: hint),
            ).marginOnly(top: 4),
          if (loading) const LinearProgressIndicator().marginOnly(top: 16),
          if (usedUp)
            Text(
              translate("You've used today's messages. You can send more tomorrow."),
              style: const TextStyle(color: Colors.orange),
            ).marginOnly(top: 14),
          if (!loading && !usedUp && channels.isNotEmpty) ...[
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
            ).marginOnly(top: 12),
            Text(translate('Send via')).marginOnly(top: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: channels
                  .map((c) => _diceXChannelOption(context, c, c == channel,
                      sending ? null : () => setState(() => channel = c)))
                  .toList(),
            ).marginOnly(top: 6),
            if (channel == 'sms')
              Text(
                translate('SMS reaches local numbers only. Use WhatsApp for other countries.'),
                style: TextStyle(fontSize: 12, color: hint),
              ).marginOnly(top: 6),
            if (remaining != null && limit != null)
              Text(
                '${translate('Messages left today')}: $remaining / $limit',
                style: TextStyle(fontSize: 12, color: hint),
              ).marginOnly(top: 12),
          ],
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)).marginOnly(top: 10),
          if (sending) const LinearProgressIndicator().marginOnly(top: 10),
        ],
      ),
      actions: usedUp
          ? [dialogButton('OK', onPressed: dismiss)]
          : [
              dialogButton('Cancel', onPressed: dismiss, isOutline: true),
              dialogButton('Send', onPressed: canSend ? submit : null),
            ],
      onSubmit: usedUp ? dismiss : submit,
      onCancel: dismiss,
    );
  });

  final options = await _diceXInviteOptions(api, id);
  if (closed) return;
  // The builder reads these when it next runs, whether or not it has run yet.
  loading = false;
  channels = options.channels;
  channel = channels.isNotEmpty ? channels.first : '';
  limit = options.limit;
  remaining = options.remaining;
  error = options.error;
  try {
    update?.call(() {});
  } catch (_) {
    // Closed some other way (all dialogs dismissed) while the service was answering.
  }
}
