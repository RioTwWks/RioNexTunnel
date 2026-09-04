import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
bool qrScannerSupported() => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
class QrScanScreen extends StatefulWidget { const QrScanScreen({super.key}); @override State<QrScanScreen> createState()=>_S(); }
class _S extends State<QrScanScreen> { final _c=MobileScannerController(); var _d=false; @override void dispose(){_c.dispose();super.dispose();}
@override Widget build(BuildContext c)=>Scaffold(appBar: AppBar(title: const Text('Scan QR code')), body: MobileScanner(controller:_c,onDetect:(x){if(_d)return;final v=x.barcodes.firstOrNull?.rawValue?.trim();if(v==null||v.isEmpty)return;_d=true;Navigator.pop(context,v);})); }
Future<String?> collectQrOrPasteText(BuildContext context) async { if(qrScannerSupported()) return Navigator.push<String>(context, MaterialPageRoute(builder:(_)=>const QrScanScreen())); final ctrl=TextEditingController(); final v=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Paste config link'),content:TextField(controller:ctrl,maxLines:5),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,ctrl.text.trim()),child:const Text('Import'))])); ctrl.dispose(); return v; }
