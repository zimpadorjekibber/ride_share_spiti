import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// One place for "tap → open the phone dialer".
///
/// Every call button used to re-implement this, and the Stay / Food cards
/// only showed a "Calling …" snackbar without ever opening the dialer — the
/// single most important action in those two modes silently did nothing.
///
/// Never throws: if no dialer is available (desktop/web, or a device without
/// telephony) the number is copied to the clipboard so the user can still use
/// it — much better than a dead button in a valley with one bar of signal.
Future<void> dialPhone(BuildContext context, String phone) async {
  final messenger = ScaffoldMessenger.of(context);
  final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (clean.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('This listing has no phone number.')),
    );
    return;
  }

  final uri = Uri.parse('tel:$clean');
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // fall through to the clipboard fallback
  }

  await Clipboard.setData(ClipboardData(text: phone));
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: const Color(0xFF334155),
      content: Text('Dialer not available — $phone copied to clipboard.'),
    ),
  );
}
