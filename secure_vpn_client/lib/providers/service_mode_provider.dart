import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/service_mode_preference.dart';
import '../providers/vpn_providers.dart';
const _k='service_mode_preference';
final serviceModePreferenceProvider=StateNotifierProvider<ServiceModePreferenceNotifier,ServiceModePreference>((ref)=>ServiceModePreferenceNotifier(ref));
class ServiceModePreferenceNotifier extends StateNotifier<ServiceModePreference>{ServiceModePreferenceNotifier(this._ref):super(ServiceModePreference.auto){_load();}
final Ref _ref;
Future<void>_load()async{final p=await SharedPreferences.getInstance();state=ServiceModePreference.fromStorage(p.getString(_k));await _ref.read(vpnServiceProvider).applyServiceMode(state);}
Future<void>setPreference(ServiceModePreference pref)async{state=pref;final p=await SharedPreferences.getInstance();await p.setString(_k,pref.storageName);await _ref.read(vpnServiceProvider).applyServiceMode(pref);}}
bool isDesktopPlatform()=>!kIsWeb&&(Platform.isLinux||Platform.isWindows||Platform.isMacOS);
