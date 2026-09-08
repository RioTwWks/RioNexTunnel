
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
abstract class PanelTokenStorage { Future<String?> readToken(); Future<void> writeToken(String t); Future<void> deleteToken(); }
class SecurePanelTokenStorage implements PanelTokenStorage { SecurePanelTokenStorage({FlutterSecureStorage? s}):_s=s??const FlutterSecureStorage(); static const _k='panel_device_token_v1'; final FlutterSecureStorage _s; @override Future<String?> readToken()=>_s.read(key:_k); @override Future<void> writeToken(String t)=>_s.write(key:_k,value:t); @override Future<void> deleteToken()=>_s.delete(key:_k);} 
class InMemoryPanelTokenStorage implements PanelTokenStorage { String? token; @override Future<void> deleteToken() async=>token=null; @override Future<String?> readToken() async=>token; @override Future<void> writeToken(String v) async=>token=v; }
