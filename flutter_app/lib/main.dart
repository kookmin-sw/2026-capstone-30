import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'constants.dart';
import 'screens/home_screen.dart';
import 'screens/saved_screen.dart' show SavedScreen, SavedScreenState;
import 'screens/shopping_screen.dart';
import 'screens/profile_screen.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'fridge_recipe_channel',
  '냉집사 알림',
  description: '냉집사 앱 알림',
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await _localNotifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);

  await FirebaseMessaging.instance
      .setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const FridgeRecipeApp());
}

class FridgeRecipeApp extends StatelessWidget {
  const FridgeRecipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '냉장고 레시피',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      home: const MainNavigator(),
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _index = 0;
  final _savedKey = GlobalKey<SavedScreenState>();
  final _homeKey = GlobalKey<HomeScreenState>();
  final _shoppingKey = GlobalKey<ShoppingScreenState>();

  final _api = ApiService();
  final _storage = StorageService();

  bool _loggedIn = false;
  bool _checking = true;
  bool _migrating = false;

  @override
  void initState() {
    super.initState();
    _check();
    _initNotification();
  }

  Future<void> _initNotification() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await messaging.getToken();
      if (token != null) await _saveToken(token);
      messaging.onTokenRefresh.listen((t) => _saveToken(t));
    }

    // 포그라운드 알림: 시스템 배너로 표시
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });

    // 백그라운드 상태에서 알림 탭
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 종료 상태에서 알림 탭으로 앱 실행
    final initial = await messaging.getInitialMessage();
    if (initial != null) _handleNotificationTap(initial);
  }

  void _handleNotificationTap(RemoteMessage message) {
    final screen = message.data['screen'];
    int targetIndex = 0;
    if (screen == 'shopping') targetIndex = 2;
    else if (screen == 'saved') targetIndex = 1;
    else if (screen == 'profile') targetIndex = 3;
    if (mounted) setState(() => _index = targetIndex);
  }

  Future<void> _saveToken(String token) async {
    final info = await _storage.getLoginInfo();
    if (info == null) return;
    try {
      await _api.saveFcmToken(info['userId'] as int, token);
    } catch (_) {}
  }

  Future<void> _check() async {
    final info = await _storage.getLoginInfo();
    if (!mounted) return;
    setState(() { _loggedIn = info != null; _checking = false; });
  }

  // 로그인,회원가입 성공하면 로컬 데이터를 DB로
  Future<void> _onLoginSuccess() async {
    setState(() { _loggedIn = true; _migrating = true; });

    try {
      await _migrate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('일부 데이터 동기화 실패: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.orange,
        ));
      }
    } finally {
      if (mounted) setState(() => _migrating = false);
    }

    // 로그인 후 FCM 토큰 서버에 전송
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _saveToken(token);

    _homeKey.currentState?.reloadFromServer();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('로그인되었습니다. 데이터가 동기화되었어요.'),
        backgroundColor: kPrimary,
      ));
    }
  }

  Future<void> _migrate() async {
    final info = await _storage.getLoginInfo();
    if (info == null) return;
    final userId = info['userId'] as int;

    // 로컬 프로필에서 DB로
    final profile = await _storage.getProfile();
    final hasProfile = profile.allergies.isNotEmpty ||
        profile.preferredCuisines.isNotEmpty ||
        profile.dietaryRestriction != '없음';
    if (hasProfile) {
      try {
        await _api.updateProfile(userId, profile.dietTypeEnglish, profile.allergyIds, profile.cuisineIds);
      } catch (_) {}
    }

    // 로컬 식재료에서 DB로
    final local = await _storage.getIngredients();
    if (local.isNotEmpty) {
      List<String> existing = [];
      try {
        final db = await _api.getIngredients(userId);
        existing = db.map((e) => e['name'] as String).toList();
      } catch (_) {}

      final seen = <String>{};
      final upload = <Map<String, dynamic>>[];
      for (final item in local) {
        final name = (item['name'] as String?)?.trim() ?? '';
        if (name.isEmpty || existing.contains(name) || !seen.add(name)) continue;
        upload.add({'name': name, 'category': item['category'] ?? '기타'});
      }
      if (upload.isNotEmpty) {
        try { await _api.saveIngredients(userId, upload); } catch (_) {}
      }
    }

    // 로컬 식재료 캐시 빼기
    await _storage.saveIngredients([]);

    // 서버 프로필을 로컬에 동기화
    try {
      final serverProfile = await _api.getProfile(userId);
      await _storage.saveProfile(serverProfile);
    } catch (_) {}
  }

  Future<void> _onLogout() async {
    // 로그아웃 전 FCM 토큰 삭제
    final info = await _storage.getLoginInfo();
    if (info != null) {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        try { await _api.deleteFcmToken(info['userId'] as int, token); } catch (_) {}
      }
    }
    await _storage.logout();
    await _storage.saveIngredients([]);
    if (!mounted) return;
    setState(() => _loggedIn = false);
    _homeKey.currentState?.reloadFromServer();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(
            index: _index,
            children: [
              HomeScreen(
                key: _homeKey,
                loggedIn: _loggedIn,
                onAddToShopping: (ings, name) => _shoppingKey.currentState?.addItems(ings, name),
              ),
              SavedScreen(key: _savedKey),
              ShoppingScreen(key: _shoppingKey),
              ProfileScreen(
                loggedIn: _loggedIn,
                onLoginSuccess: _onLoginSuccess,
                onLogout: _onLogout,
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) {
              if (i == 1) _savedKey.currentState?.reload();
              setState(() => _index = i);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: '홈',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmark_outline),
                selectedIcon: Icon(Icons.bookmark),
                label: '저장',
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_cart_outlined),
                selectedIcon: Icon(Icons.shopping_cart),
                label: '쇼핑',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: '프로필',
              ),
            ],
          ),
        ),
        if (_migrating)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x66000000),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 16),
                      Text('데이터 동기화 중...', style: TextStyle(fontSize: 15)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
