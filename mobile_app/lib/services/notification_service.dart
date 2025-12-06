import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for important notifications.',
    importance: Importance.high,
  );

  final _healthTips = [
    'Lembre-se de beber bastante água durante o dia para se manter hidratado!',
    'Tente fazer pelo menos 30 minutos de atividade física todos os dias.',
    'Uma dieta balanceada é a chave para uma vida saudável. Inclua frutas e vegetais em suas refeições.',
    'Durma de 7 a 8 horas por noite para uma boa recuperação do corpo e da mente.',
    'Não se esqueça de alongar o corpo, especialmente se você passa muito tempo sentado.',
    'Pequenas pausas durante o trabalho para caminhar um pouco podem fazer uma grande diferença.',
    'Reduza o consumo de açúcar e alimentos processados.',
    'A saúde mental é tão importante quanto a física. Reserve um tempo para relaxar e fazer o que gosta.',
    'Lave as mãos com frequência para evitar a propagação de germes.',
    'Consulte um médico regularmente para check-ups e exames preventivos.',
  ];

  Future<void> initialize() async {
    // Configura o fuso horário local para o agendamento de notificações
    tz.initializeTimeZones();

    // Inicialização Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Inicialização iOS
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    // Combinação
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(settings);

    // Criação do canal Android para notificações de alta importância
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Criação do canal para dicas de saúde semanais
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'weekly_health_tip_channel', // id
          'Dicas de Saúde Semanais', // title
          description: 'Canal para dicas de saúde semanais.', // description
          importance: Importance.low,
        ));

    // Permissões iOS
    await FirebaseMessaging.instance.requestPermission();
  }

  // Exibir notificação local
  Future<void> showNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification == null) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: android?.smallIcon ?? '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
    );
  }

  // Exibe uma notificação local com uma dica de saúde aleatória
  Future<void> showRandomHealthTipNow() async {
    final randomTip = _healthTips[Random().nextInt(_healthTips.length)];

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'Canal para notificações importantes.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      0, // ID da notificação
      'Dica de Saúde', // Título
      randomTip, // Corpo
      notificationDetails,
    );
  }

  /// Agenda uma notificação semanal com uma dica de saúde em um horário específico.
  Future<void> scheduleWeeklyHealthTip({TimeOfDay? time}) async {
    // Define um horário padrão caso nenhum seja fornecido
    final scheduleTime = time ?? const TimeOfDay(hour: 10, minute: 0);
    final randomTip = _healthTips[Random().nextInt(_healthTips.length)];

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      2, // ID único para esta notificação agendada
      'Sua Dica de Saúde Semanal',
      randomTip,
      _nextInstanceOfSundayAt(scheduleTime),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_health_tip_channel',
          'Dicas de Saúde Semanais',
          channelDescription: 'Canal para dicas de saúde semanais.',
        ),
        iOS: DarwinNotificationDetails(sound: 'default'),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Calcula a próxima ocorrência de um domingo no horário especificado.
  tz.TZDateTime _nextInstanceOfSundayAt(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    while (scheduledDate.weekday != DateTime.sunday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
