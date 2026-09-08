import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/app_localizations.dart';

bool qrScannerSupported() => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  var _detected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.qrScanTitle)),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          if (_detected) {
            return;
          }
          final value = capture.barcodes.firstOrNull?.rawValue?.trim();
          if (value == null || value.isEmpty) {
            return;
          }
          _detected = true;
          Navigator.pop(context, value);
        },
      ),
    );
  }
}

Future<String?> collectQrOrPasteText(BuildContext context) async {
  if (qrScannerSupported()) {
    return Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
  }

  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.qrPasteConfigLink),
      content: TextField(controller: controller, maxLines: 5),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: Text(l10n.qrImport),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}
