import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_log_level.dart';
class AppLogEntry{const AppLogEntry({required this.timestamp,required this.level,required this.message,this.redacted=false});final String timestamp,level,message;final bool redacted;String get displayLine=>'$timestamp [$level] ${redacted?'[REDACTED] ':''}$message';}
class AppLog{AppLog._();static const _max=2097152;static IOSink?_sink;static File?_file;static Future<void> _chain=Future.value();static AppLogLevel _min=AppLogLevel.info;static void setMinimumLevel(AppLogLevel l)=>_min=l;static Future<String?> logDirectoryPath()async{try{return (await _ensureDir()).path;}catch(_){return null;}}
static void info(String m)=>_w('INFO',m);static void debug(String m){if(_min.includesDebug())_w('DEBUG',m);}
static Future<List<AppLogEntry>> readRecentLines({bool includeDebug=false})async{try{final f=await _ensureFile();if(!await f.exists())return[];final lines=(await f.readAsString()).split('\n').where((l)=>l.trim().isNotEmpty).toList();final out=<AppLogEntry>[];for(final line in lines){final e=_parse(line);if(e!=null&& (includeDebug||e.level!='DEBUG'))out.add(e);}return out;}catch(e){debugPrint('[AppLog] $e');return[];}}
static AppLogEntry?_parse(String line){final m=RegExp(r'^(\S+)\s+\[(\w+)\]\s*(.*)$').firstMatch(line.trim());if(m==null){final s=scrubMessage(line);return AppLogEntry(timestamp:'',level:'INFO',message:s.message,redacted:s.redacted);}final s=scrubMessage(m.group(3)??'');return AppLogEntry(timestamp:m.group(1)??'',level:m.group(2)??'INFO',message:s.message,redacted:s.redacted);}
static({String message,bool redacted}) scrubMessage(String m){if(_leak(m))return(message:'credential field redacted',redacted:true);return(message:m,redacted:false);}
static void _w(String level,String m){final t=m.trim();if(t.isEmpty)return;if(level=='DEBUG'&&!_min.includesDebug())return;if(_leak(t)){debugPrint('[AppLog] skipped leak');return;}final line='${DateTime.now().toIso8601String()} [$level] $t';debugPrint(line);_chain=_chain.then((_)=>_append(line));}
static Future<void>_append(String line)async{try{final f=await _ensureFile();final s=_sink??=(await _ensureFile()).openWrite(mode:FileMode.append);s.writeln(line);await s.flush();}catch(e){debugPrint('[AppLog] $e');}}
static Future<Directory>_ensureDir()async{final d=Directory('${(await getApplicationSupportDirectory()).path}/logs');if(!await d.exists())await d.create(recursive:true);return d;}
static Future<File>_ensureFile()async{_file??=File('${(await _ensureDir()).path}/app.log');return _file!;}
static bool _leak(String m){final l=m.toLowerCase();return l.contains('"pass"')||l.contains('"password"')||l.contains('device_token');}
}
