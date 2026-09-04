import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_log_level_provider.dart';
import '../services/app_log.dart';
class LogViewerScreen extends ConsumerStatefulWidget{const LogViewerScreen({super.key});@override ConsumerState<LogViewerScreen> createState()=>_S();}
class _S extends ConsumerState<LogViewerScreen>{List<AppLogEntry> _e=const[];bool _l=true;@override void initState(){super.initState();_r();}
Future<void>_r()async{setState(()=>_l=true);final e=await AppLog.readRecentLines(includeDebug:ref.read(appLogLevelProvider).includesDebug());if(mounted)setState((){_e=e;_l=false;});}
@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Logs'),actions:[IconButton(onPressed:_r,icon:const Icon(Icons.refresh)),IconButton(onPressed:_e.isEmpty?null:()=>Clipboard.setData(ClipboardData(text:_e.map((x)=>x.displayLine).join('\n'))),icon:const Icon(Icons.copy))]),body:_l?const Center(child:CircularProgressIndicator()):ListView.builder(padding:const EdgeInsets.all(16),itemCount:_e.length,itemBuilder:(_,i)=>SelectableText(_e[i].displayLine,style:const TextStyle(fontFamily:'monospace',fontSize:12))));
}
