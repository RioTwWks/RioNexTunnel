import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_log_level.dart';
import '../services/app_log.dart';
const _k='app_log_level';
final appLogLevelProvider=StateNotifierProvider<AppLogLevelNotifier,AppLogLevel>((ref)=>AppLogLevelNotifier());
class AppLogLevelNotifier extends StateNotifier<AppLogLevel>{AppLogLevelNotifier():super(AppLogLevel.info){_load();}
Future<void>_load()async{final p=await SharedPreferences.getInstance();final s=AppLogLevel.fromStorage(p.getString(_k));state=s;AppLog.setMinimumLevel(s);}
Future<void>setLevel(AppLogLevel l)async{state=l;AppLog.setMinimumLevel(l);final p=await SharedPreferences.getInstance();await p.setString(_k,l.storageName);}}
