import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import 'screens/mapa_postos_screen.dart';
import 'screens/campanhas_screen.dart';
import 'firebase_options.dart';

/// =======================================================
/// HANDLER PARA MENSAGENS EM BACKGROUND
/// =======================================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint("===== MENSAGEM EM BACKGROUND =====");
  debugPrint("Título: ${message.notification?.title}");
  debugPrint("Corpo: ${message.notification?.body}");
  debugPrint("Dados: ${message.data}");
}

/// =======================================================
/// FUNÇÃO PRINCIPAL
/// =======================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase corretamente
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Registrar handler de background ANTES do runApp()
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

/// =======================================================
/// CONFIGURAÇÃO DO FIREBASE MESSAGING
/// =======================================================
Future<void> setupFirebaseMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Pedir permissão
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    debugPrint("Permissão de notificação concedida!");

    // Obter token FCM
    String? token = await messaging.getToken();
    debugPrint("TOKEN FCM: $token");

    if (token != null) {
      try {
        await http.post(
          Uri.parse("http://192.168.18.210:8000/registrar-dispositivo"),
          body: {"token": token},
        );
        debugPrint("Token enviado ao backend!");
      } catch (e) {
        debugPrint("Erro ao enviar token: $e");
      }
    }
  } else {
    debugPrint("Permissão de notificação negada pelo usuário.");
  }

  /// RECEBENDO NOTIFICAÇÕES COM O APP ABERTO
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint("===== NOTIFICAÇÃO EM FOREGROUND =====");
    debugPrint("Título: ${message.notification?.title}");
    debugPrint("Corpo: ${message.notification?.body}");
    debugPrint("Dados: ${message.data}");
  });

  /// NOTIFICAÇÃO CLICADA PELO USUÁRIO
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint("Usuário abriu o app clicando na notificação");
    debugPrint("Dados: ${message.data}");
  });
}

/// =======================================================
/// APP PRINCIPAL
/// =======================================================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    setupFirebaseMessaging(); // Configura notificações
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Guia Saúde Local",

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),

      home: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: const [
            MapaPostosScreen(),
            CampanhasScreen(),
          ],
        ),

        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map),
              label: "Postos",
            ),
            NavigationDestination(
              icon: Icon(Icons.campaign),
              label: "Campanhas",
            ),
          ],
        ),
      ),
    );
  }
}
