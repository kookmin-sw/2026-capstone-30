import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDVIwipKS_zxq1CCbZVvkLTw9k8Jgny8RQ',
    authDomain: 'capstone-ee3c1.firebaseapp.com',
    projectId: 'capstone-ee3c1',
    storageBucket: 'capstone-ee3c1.firebasestorage.app',
    messagingSenderId: '450995657813',
    appId: '1:450995657813:web:4d485131e7b87838f048dc',
    measurementId: 'G-5CC3G5JGB8',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAxzz7X3p16PavicsRtmItN10wF5WTbx30',
    projectId: 'capstone-ee3c1',
    storageBucket: 'capstone-ee3c1.firebasestorage.app',
    messagingSenderId: '450995657813',
    appId: '1:450995657813:android:5f01bb4aadf9fe46f048dc',
  );
}
