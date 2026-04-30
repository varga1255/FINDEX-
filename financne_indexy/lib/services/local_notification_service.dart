import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    await _requestPermissionIfNeeded();
  }

  Future<void> showBuySignalsNotification(List<String> lines) async {
    await _requestPermissionIfNeeded();
    final body = lines.isEmpty
        ? 'Momentálne nie sú žiadne indexy v stave BUY alebo BUY++.'
        : lines.join('\n');
    final androidDetails = AndroidNotificationDetails(
      'mcs_buy_signals',
      'FMCS BUY signály',
      channelDescription:
          'Lokálne upozornenia na indexy v stave BUY alebo BUY++',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
    );
    final details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      1001,
      'PVA FMCS BUY signály',
      body,
      details,
    );
  }

  Future<void> _requestPermissionIfNeeded() async {
    final androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.requestNotificationsPermission();
  }
}
