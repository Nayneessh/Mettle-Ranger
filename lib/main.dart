import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Deliberately not awaited: AppConfig.init() only brings up optional
  // third-party SDKs (Supabase, AdMob, RevenueCat, the daily reminder) that
  // spec §11 says must never gate a core feature. Awaiting it here — as a
  // prior version of this file did — meant the engine never rendered a
  // single frame, not even app.dart's own splash, until every one of those
  // SDK calls resolved; any one of them stalling (no network, no Play
  // Services, a permission dialog nobody's answered yet) looked from
  // outside like the app being stuck on its launch screen forever.
  unawaited(AppConfig.instance.init());
  runApp(const ProviderScope(child: MettleRangerApp()));
}
