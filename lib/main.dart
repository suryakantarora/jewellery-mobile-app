import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/storage/local_store.dart';
import 'core/storage/secure_storage.dart';
import 'features/notifications/data/push_registration_service.dart';

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

  final firebaseReady = await _initFirebase();

  runApp(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(localStore),
        firebaseReadyProvider.overrideWithValue(firebaseReady),
      ],
      child: const JewelleryErpApp(),
    ),
  );
}

/// Firebase is optional. A build without `google-services.json` /
/// `GoogleService-Info.plist` throws here; the app then runs on polling only
/// and logs once. Nothing else in the app calls Firebase unless this is true.
Future<bool> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    return true;
  } on Object catch (error) {
    debugPrint('Firebase not configured; push disabled ($error)');
    return false;
  }
}
