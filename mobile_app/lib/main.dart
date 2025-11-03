import 'package:flutter/material.dart';
import 'screens/mapa_postos_screen.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Importe
import 'package:http/http.dart' as http;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Se você inicializar o Firebase, pode fazer lógica de API aqui
  // await Firebase.initializeApp();

  print("--- MENSAGEM EM SEGUNDO PLANO RECEBIDA ---");
  print("Título: ${message.notification?.title}");
  print("Corpo: ${message.notification?.body}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      // options: DefaultFirebaseOptions.currentPlatform, // (Use se você usou o FlutterFire CLI)
      );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);      
  runApp(const MyApp());
}

Future<void> setupFirebaseMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // 1. Pedir permissão ao usuário (iOS e Android 13+)
  NotificationSettings settings = await messaging.requestPermission();

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('Permissão de notificação concedida!');

    // 2. Obter o token do dispositivo
    String? token = await messaging.getToken();

    if (token != null) {
      print('FCM Token: $token');
      // 3. Enviar o token para o seu back-end
      try {
        // (Use o mesmo IP/URL do seu ApiService)
        await http.post(
          Uri.parse('http://192.168.18.211:8000/registrar-dispositivo'),
          body: {'token': token},
        );
        print('Token enviado para o backend com sucesso.');
      } catch (e) {
        print('Erro ao enviar token para o backend: $e');
      }
    }
  } else {
    print('Permissão de notificação negada.');
  }

  // 4. Lidar com notificações recebidas (simples)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Recebi uma mensagem com o app aberto!');
    if (message.notification != null) {
      print('Mensagem: ${message.notification!.body}');
    }
  });
}

// 1. Converte o MyApp para StatefulWidget
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

// 2. Cria o Estado para o MyApp
class _MyAppState extends State<MyApp> {
  
  // 3. Chama a função de setup dentro do initState
  @override
  void initState() {
    super.initState();
    // ESTA É A LINHA QUE FALTAVA
    setupFirebaseMessaging(); 
  }

  // 4. O método build agora fica dentro do State
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guia Saúde Local',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MapaPostosScreen(), // A tela inicial agora é a do mapa
    );
  }
}