import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

const workerUrl = String.fromEnvironment('DREAMER_WORKER_URL', defaultValue: 'https://dreamer-worker.whatthewithyking.workers.dev');

final notifications = FlutterLocalNotificationsPlugin();

Future<void> initializeDailyReminder() async {
  try {
    tz.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await notifications.initialize(settings: const InitializationSettings(android: android, iOS: ios));
    await notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, 7);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    await notifications.zonedSchedule(
      id: 700,
      title: 'Dreamer',
      body: 'Did you dream today? Tell me about it.',
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'dreamer_daily',
          'Daily dream reminder',
          channelDescription: 'A gentle morning reminder to write down your dream.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  } catch (_) {
    // Notifications are optional; the core dream interpreter still works.
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDailyReminder();
  runApp(const DreamerApp());
}

class DreamerApp extends StatelessWidget {
  const DreamerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Dreamer',
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'sans-serif', colorScheme: const ColorScheme.dark(primary: Color(0xFFB79CFF)), scaffoldBackgroundColor: const Color(0xFF090A1D)),
        home: const DreamHome(),
      );
}

class DreamHome extends StatefulWidget { const DreamHome({super.key}); @override State<DreamHome> createState() => _DreamHomeState(); }
class _DreamHomeState extends State<DreamHome> {
  final dream = TextEditingController();
  final dreamFocus = FocusNode();
  String? answer; bool loading = false; bool keyboardVisible = true;

  Future<void> interpret() async {
    if (dream.text.trim().isEmpty || loading) return;
    setState(() { loading = true; answer = null; });
    try {
      final r = await http.post(Uri.parse(workerUrl), headers: {'content-type': 'application/json'}, body: jsonEncode({'dream': dream.text.trim()}));
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode >= 400) throw Exception(data['error'] ?? 'Unable to interpret');
      setState(() => answer = data['text'] as String? ?? 'ඔබගේ සිහිනය ගැන තවත් විස්තර කියන්න.');
    } catch (_) {
      setState(() => answer = 'දරුවා, ඔබගේ සිහිනය සම්බන්ධයෙන් මෘදු ලෙස සිතා බලමු. මේ මොහොතේ සේවාව සම්බන්ධ කරගත නොහැකි නිසා, මඳ වේලාවකින් නැවත උත්සාහ කරන්න.');
    } finally { setState(() => loading = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    body: Stack(children: [
      const DreamBackdrop(),
      SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(22, 18, 22, 28), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [const DreamLogo(size: 48), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Dreamer', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)), Text('Your dreams, gently understood', style: TextStyle(color: Colors.white60, fontSize: 12))])), IconButton(icon: const Icon(Icons.more_horiz_rounded), onPressed: () => showModalBottomSheet(context: context, backgroundColor: const Color(0xFF171833), builder: (_) => const MenuSheet()))]),
        const SizedBox(height: 46),
        const Text('Tell me your dream', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.1)),
        const SizedBox(height: 8), const Text('Describe what you saw, felt, or remember. I’ll respond in the same language.', style: TextStyle(color: Colors.white70, height: 1.45)),
        const SizedBox(height: 24),
        Container(decoration: BoxDecoration(color: Colors.white.withOpacity(.09), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(.14))), child: TextField(controller: dream, focusNode: dreamFocus, minLines: 7, maxLines: 12, textInputAction: TextInputAction.send, onSubmitted: (_) => interpret(), style: const TextStyle(fontSize: 16, height: 1.45), decoration: const InputDecoration(hintText: 'Type the dream you remember…', hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none, contentPadding: EdgeInsets.all(20)))),
        const SizedBox(height: 14),
        Row(children: [OutlinedButton.icon(onPressed: () { if (keyboardVisible) { FocusScope.of(context).unfocus(); } else { dreamFocus.requestFocus(); } setState(() => keyboardVisible = !keyboardVisible); }, icon: Icon(keyboardVisible ? Icons.keyboard_hide_rounded : Icons.keyboard_rounded, size: 18), label: Text(keyboardVisible ? 'Hide keyboard' : 'Show keyboard'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13))), const Spacer(), FilledButton.icon(onPressed: interpret, icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome_rounded, size: 18), label: const Text('Interpret'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8064E8), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14))) ]),
        if (answer != null) ...[const SizedBox(height: 28), Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: const Color(0xFF171833).withOpacity(.9), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFB79CFF).withOpacity(.3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('ඔබගේ සිහිනය…', style: TextStyle(color: Color(0xFFD3C5FF), fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(height: 10), Text(answer!, style: const TextStyle(fontSize: 16, height: 1.55))]))]
      ])))
    ]));
}

class DreamBackdrop extends StatelessWidget { const DreamBackdrop({super.key}); @override Widget build(BuildContext context) => CustomPaint(painter: BackdropPainter(), child: const SizedBox.expand()); }
class BackdropPainter extends CustomPainter { @override void paint(Canvas c, Size s) { final p = Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF15143B), Color(0xFF090A1D), Color(0xFF101B38)]).createShader(Offset.zero & s); c.drawRect(Offset.zero & s, p); final glow = Paint()..color = const Color(0xFF8064E8).withOpacity(.12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80); c.drawCircle(Offset(s.width*.82, s.height*.12), 120, glow); final orbOne = Paint()..shader = const RadialGradient(center: Alignment(-.35, -.4), radius: .9, colors: [Color(0xFFBBA8FF), Color(0xFF6C55D9), Color(0xFF251D66)]).createShader(Rect.fromCircle(center: Offset(s.width*.88, s.height*.28), radius: 88)); c.drawCircle(Offset(s.width*.88, s.height*.28), 88, orbOne); final orbTwo = Paint()..shader = const RadialGradient(center: Alignment(-.4, -.5), radius: .9, colors: [Color(0xFFFFE8A8), Color(0xFFD68BFF), Color(0xFF4C327B)]).createShader(Rect.fromCircle(center: Offset(s.width*.12, s.height*.62), radius: 42)); c.drawCircle(Offset(s.width*.12, s.height*.62), 42, orbTwo); } @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false; }
class DreamLogo extends StatelessWidget { final double size; const DreamLogo({super.key, required this.size}); @override Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFFA78BFA), Color(0xFF5145A7)]), boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(.35), blurRadius: 18)]), child: Icon(Icons.nightlight_round, size: size*.55, color: const Color(0xFFFFE9A8))); }

class MenuSheet extends StatelessWidget { const MenuSheet({super.key}); @override Widget build(BuildContext context) => SafeArea(child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, children: [const Align(alignment: Alignment.centerLeft, child: Text('Dreamer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))), const SizedBox(height: 14), ListTile(leading: const Icon(Icons.info_outline_rounded), title: const Text('About developer'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage()))), ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('Privacy Policy'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPage()))), const SizedBox(height: 8)]))); }
class SimplePage extends StatelessWidget { final String title; final Widget child; const SimplePage({super.key, required this.title, required this.child}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title), backgroundColor: Colors.transparent), body: SingleChildScrollView(padding: const EdgeInsets.all(22), child: child)); }
class AboutPage extends StatelessWidget { const AboutPage({super.key}); @override Widget build(BuildContext context) => SimplePage(title: 'About developer', child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: DreamLogo(size: 90)), SizedBox(height: 22), Text('LankaKnot Software Solutions', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)), SizedBox(height: 12), Text('We create thoughtful software solutions that make everyday technology simpler, more useful, and more beautiful. Dreamer is designed to give people a calm space to reflect on their dreams and explore their personal meaning.', style: TextStyle(fontSize: 16, height: 1.6)), SizedBox(height: 22), Text('Contact', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFD3C5FF))), SizedBox(height: 6), Text('lankaknot@gmail.com', style: TextStyle(fontSize: 16))])); }
class PrivacyPage extends StatelessWidget { const PrivacyPage({super.key}); @override Widget build(BuildContext context) => SimplePage(title: 'Privacy Policy', child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Dreamer Privacy Policy', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)), SizedBox(height: 8), Text('Last updated: November 1, 2026', style: TextStyle(color: Colors.white60)), SizedBox(height: 22), Text('Dreamer is designed to work without accounts, login, or sign-up.', style: TextStyle(fontSize: 16, height: 1.5)), SizedBox(height: 18), Text('What we process', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFD3C5FF))), SizedBox(height: 6), Text('When you submit a dream, the text is sent securely to our Cloudflare Worker and then to the configured Gemini model to generate an interpretation. We do not ask for your name, email, or account details.', style: TextStyle(height: 1.55)), SizedBox(height: 18), Text('Data retention', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFD3C5FF))), SizedBox(height: 6), Text('Dream entries are not stored by the app. Network providers and AI services may process requests according to their own policies. Do not submit highly sensitive personal information.', style: TextStyle(height: 1.55)), SizedBox(height: 18), Text('Contact', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFD3C5FF))), SizedBox(height: 6), Text('Questions: lankaknot@gmail.com', style: TextStyle(height: 1.55))])); }
