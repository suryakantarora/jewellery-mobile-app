import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/storage/local_store.dart';
import 'core/storage/secure_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only: every layout in this app is designed for a device held one
  // handed at a counter or in a vault, and landscape adds nothing but risk.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Preferences are read once, before the first frame, so no widget has to
  // await storage during build and the theme never flashes the wrong way.
  final localStore = await LocalStore.create();

  // The iOS Keychain survives an app being deleted, so a fresh install can
  // find credentials from a previous installation. Preferences do not survive,
  // which is what makes a genuine first run detectable.
  await SecureStorage().clearIfFreshInstall(localStore);

  runApp(
    ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(localStore)],
      child: const JewelleryErpApp(),
    ),
  );
}
