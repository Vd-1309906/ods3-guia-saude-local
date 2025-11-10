import 'package:flutter/material.dart';
import 'screens/mapa_postos_screen.dart'; 
import 'screens/campanhas_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:http/http.dart' as http;

// 1. IMPORTAÇÃO ADICIONADA (Gerada pelo 'flutterfire configure')
import 'firebase_options.dart'; 

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Se precisar de lógica de API aqui, inicialize o Firebase
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("--- MENSAGEM EM SEGUNDO PLANO RECEBIDA ---");
  debugPrint("Título: ${message.notification?.title}");
  debugPrint("Corpo: ${message.notification?.body}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. CORREÇÃO DA INICIALIZAÇÃO DO FIREBASE
  // Agora usa o 'options' para ser compatível com todas as plataformas
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform, 
  );
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);      
  runApp(const MyApp());
}

Future<void> setupFirebaseMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission();

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
  debugPrint('Permissão de notificação concedida!');

    String? token = await messaging.getToken();

  if (token != null) {
  debugPrint('FCM Token: $token');
  try {
        // --- ATENÇÃO (LEMBRETE) ---
        // Este IP (192.168.18.211) é o IP do seu PC na rede Wi-Fi.
        // Se o seu PC mudar de IP, o app deixará de funcionar
        // até você atualizar este IP aqui.
        await http.post(
          Uri.parse('http://192.168.18.211:8000/registrar-dispositivo'),
          body: {'token': token},
        );
  debugPrint('Token enviado para o backend com sucesso.');
        } catch (e) {
        // (Para um app real, mostraríamos um erro ao utilizador aqui)
        debugPrint('Erro ao enviar token para o backend: $e');
      }
    }
  } else {
    debugPrint('Permissão de notificação negada.');
  }

  // Lidar com notificações com o app aberto
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Recebi uma mensagem com o app aberto!');
    if (message.notification != null) {
      debugPrint('Mensagem: ${message.notification!.body}');
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  
  @override
  void initState() {
    super.initState();
    setupFirebaseMessaging(); 
  }

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guia Saúde Local',
      
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
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
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map),
              label: 'Postos',
            ),
            NavigationDestination(
              icon: Icon(Icons.campaign),
              label: 'Campanhas',
            ),
          ],
        ),
      ),
    );
  }
}