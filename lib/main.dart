import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'firebase_options.dart';
import 'services/reader_tts_service.dart';
import 'services/reader_narration_progress_repository.dart';
import 'services/reader_narration_progress_controller.dart';
import 'services/reader_narration_navigator.dart';
import 'services/reader_narration_preferences_repository.dart';
import 'services/reader_narration_preferences_controller.dart';
import 'services/reader_narration_access_policy.dart';
import 'services/reader_narration_voice.dart';
import 'services/reader_narration_session_repository.dart';
import 'services/reader_narration_session_tracker.dart';
import 'services/reader_narration_playback_coordinator.dart';
import 'services/reader_narration_voice_catalog_presenter.dart';
import 'services/reader_bookmark_repository.dart';
import 'services/reader_device_identity.dart';
import 'services/reader_highlight_repository.dart';
import 'services/reader_note_repository.dart';
import 'services/reader_saved_position_repository.dart';
import 'services/reader_protection_policy.dart';
import 'services/reader_workspace_filters.dart';
import 'services/reader_access_decision.dart';
import 'services/reader_activity_analytics.dart';
import 'services/reader_activity_repository.dart';
import 'services/user_access_repository.dart';
import 'services/user_device_authorization_repository.dart';
import 'services/user_access_state.dart';
import 'services/vault_document_metadata.dart';
import 'services/vault_search_snippet.dart';
import 'services/reader_cloud_narration_audio_player_factory.dart';
import 'services/reader_cloud_narration_playback_controller.dart';
import 'services/reader_cloud_narration_preparation_queue.dart';
import 'services/reader_cloud_narration_registry.dart';
import 'services/reader_cloud_narration_session_coordinator.dart';
import 'services/reader_cloud_narration_callable_provider.dart';
import 'services/reader_cloud_narration_http_callable_client.dart';
import 'widgets/reader_narration_dialog.dart';
import 'widgets/reader_text_selection_dialog.dart';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui_web' as ui;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

const UserDeviceAuthorizationMode readerDeviceAuthorizationMode =
    UserDeviceAuthorizationMode.monitoring;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const AncientSecureDocsApp());
}

class AncientSecureDocsApp extends StatelessWidget {
  const AncientSecureDocsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ancient Secure Docs',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF0F1117),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          'Ancient Secure Docs',
          style: TextStyle(
            color: Colors.greenAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                const Text(
                  'Welcome to Ancient Secure Docs',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  'A secure knowledge ecosystem for protected books, confidential documents, audio learning, highlighting, notes, and encrypted educational access.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 35),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.greenAccent),
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Core Features',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 15),

                      Text(
                        '- Secure PDF Streaming\n'
                        '- Text-to-Speech Audio Reading\n'
                        '- Highlights & Smart Notes\n'
                        '- Subscription Access\n'
                        '- Reading Progress Tracking\n'
                        '- Watermark Security\n'
                        '- Encrypted Content Access',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 60,

                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),

                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },

                    child: const Text(
                      'ENTER PLATFORM',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Login', style: TextStyle(color: Colors.greenAccent)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30),

                const Text(
                  'Welcome Back',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Login to continue into the secure ecosystem.',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),

                const SizedBox(height: 40),

                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Email Address',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () async {
                      try {
                        await FirebaseAuth.instance.signInWithEmailAndPassword(
                          email: emailController.text.trim(),
                          password: passwordController.text.trim(),
                        );

                        if (!context.mounted) return;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DashboardScreen(),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;

                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    },
                    child: const Text(
                      'LOGIN',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _ReaderNoteEditResult {
  const _ReaderNoteEditResult({required this.note, required this.category});

  final String note;
  final String category;
}

class _ReaderHighlightDetailsResult {
  const _ReaderHighlightDetailsResult({
    required this.color,
    required this.note,
  });

  final String color;
  final String note;
}

class HtmlDeviceIdentityStorage implements ReaderDeviceIdentityStorage {
  const HtmlDeviceIdentityStorage();

  @override
  String? read(String key) {
    return html.window.localStorage[key];
  }

  @override
  void write(String key, String value) {
    html.window.localStorage[key] = value;
  }
}

class _DashboardAdminOverview {
  const _DashboardAdminOverview({
    required this.users,
    required this.devices,
    required this.activity,
  });

  final UserAccessSummary users;
  final UserDeviceSummary devices;
  final ReaderActivitySummary activity;
}

enum _AdminAttentionTone { danger, warning, info, success }

class _AdminAttentionItem {
  const _AdminAttentionItem({
    required this.icon,
    required this.title,
    required this.detail,
    required this.tone,
    this.actionLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String detail;
  final _AdminAttentionTone tone;
  final String? actionLabel;
  final VoidCallback? onPressed;
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> freePdfFiles = [];
  List<Map<String, dynamic>> premiumPdfFiles = [];

  bool isLoading = false;
  UserAccessState userAccess = const UserAccessState();
  String? pdfLoadError;
  String searchMode = 'all';
  String accessFilter = 'all';
  String dashboardDocumentSearchQuery = '';
  String freeDocumentCategoryFilter = '';
  String premiumDocumentCategoryFilter = '';
  final TextEditingController dashboardDocumentSearchController =
      TextEditingController();
  List<Map<String, dynamic>> userNotes = [];
  final ReaderNoteRepository readerNoteRepository = ReaderNoteRepository();
  final ReaderActivityRepository readerActivityRepository =
      ReaderActivityRepository();
  final UserAccessRepository userAccessRepository = UserAccessRepository();
  final UserDeviceAuthorizationRepository deviceAuthorizationRepository =
      UserDeviceAuthorizationRepository();
  Future<_DashboardAdminOverview>? adminOverviewFuture;

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    await checkUserRole();
    await loadPDFs();
  }

  Future<_DashboardAdminOverview> loadDashboardAdminOverview() async {
    final users = await userAccessRepository.loadSummary(limit: 100);
    final devices = await deviceAuthorizationRepository.loadSummary(limit: 100);
    final activity = await readerActivityRepository.loadSummary(
      perCollectionLimit: 75,
      recentLimit: 6,
      topDocumentLimit: 4,
    );

    return _DashboardAdminOverview(
      users: users,
      devices: devices,
      activity: activity,
    );
  }

  void refreshDashboardAdminOverview() {
    if (!userAccess.isAdmin) return;

    setState(() {
      adminOverviewFuture = loadDashboardAdminOverview();
    });
  }

  @override
  void dispose() {
    dashboardDocumentSearchController.dispose();
    super.dispose();
  }

  bool requireVaultManagerAccess() {
    if (userAccess.canManageVault) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Admin access required for this vault action.'),
      ),
    );

    return false;
  }

  String formatDashboardTimestamp(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return '${date.year}-$month-$day $hour:$minute';
    }

    return 'just now';
  }

  String formatActivityLabel(ReaderActivityRecord record) {
    final label = record.activityLabel.replaceAll('_', ' ').trim();
    if (label.isEmpty) return 'Reader activity';

    return label[0].toUpperCase() + label.substring(1);
  }

  String formatActivitySubtitle(ReaderActivityRecord record) {
    final parts = [
      record.pdfTitle,
      record.userEmail.isEmpty ? 'Unknown reader' : record.userEmail,
      if (record.deviceAuthorizationLabel.isNotEmpty)
        record.deviceAuthorizationLabel,
      formatDashboardTimestamp(record.createdAt),
    ].where((part) => part.trim().isNotEmpty);

    return parts.join(' | ');
  }

  Future<void> showReaderAnalytics() async {
    if (!requireVaultManagerAccess()) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return PointerInterceptor(
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F1117),
            title: const Text(
              'Reader Analytics',
              style: TextStyle(color: Colors.greenAccent),
            ),
            content: SizedBox(
              width: 520,
              child: FutureBuilder<ReaderActivitySummary>(
                future: readerActivityRepository.loadSummary(
                  perCollectionLimit: 75,
                  recentLimit: 6,
                  topDocumentLimit: 4,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      snapshot.error.toString(),
                      style: const TextStyle(color: Colors.redAccent),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.greenAccent,
                        ),
                      ),
                    );
                  }

                  final summary = snapshot.data!;
                  if (!summary.hasActivity) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No reader activity has been recorded yet.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _ReaderAnalyticsMetric(
                              label: 'Events',
                              value: summary.totalEventCount.toString(),
                            ),
                            _ReaderAnalyticsMetric(
                              label: 'Readers',
                              value: summary.uniqueReaderCount.toString(),
                            ),
                            _ReaderAnalyticsMetric(
                              label: 'Documents',
                              value: summary.uniqueDocumentCount.toString(),
                            ),
                            _ReaderAnalyticsMetric(
                              label: 'Blocked',
                              value: summary.blockedAccessCount.toString(),
                              color: Colors.orangeAccent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Top Documents',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (summary.topDocuments.isEmpty)
                          const Text(
                            'No document activity yet.',
                            style: TextStyle(color: Colors.white54),
                          )
                        else
                          ...summary.topDocuments.map(
                            (document) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.picture_as_pdf_outlined,
                                color: Colors.greenAccent,
                              ),
                              title: Text(
                                document.pdfTitle.isEmpty
                                    ? document.documentIdentity
                                    : document.pdfTitle,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: Text(
                                document.eventCount.toString(),
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        const Divider(color: Colors.white24),
                        const Text(
                          'Recent Activity',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...summary.recentRecords.map(
                          (record) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              record.isBlockedAccess
                                  ? Icons.lock_outline
                                  : Icons.timeline,
                              color: record.isBlockedAccess
                                  ? Colors.orangeAccent
                                  : Colors.greenAccent,
                            ),
                            title: Text(
                              formatActivityLabel(record),
                              style: const TextStyle(color: Colors.white70),
                            ),
                            subtitle: Text(
                              formatActivitySubtitle(record),
                              style: const TextStyle(color: Colors.white38),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.greenAccent),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> showVaultInventory() async {
    if (!requireVaultManagerAccess()) return;

    final summary = VaultDocumentInventorySummary.fromDocuments(
      freeDocuments: freePdfFiles,
      premiumDocuments: premiumPdfFiles,
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return PointerInterceptor(
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F1117),
            title: const Text(
              'Vault Inventory',
              style: TextStyle(color: Colors.greenAccent),
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ReaderAnalyticsMetric(
                          label: 'Documents',
                          value: summary.totalCount.toString(),
                        ),
                        _ReaderAnalyticsMetric(
                          label: 'Free',
                          value: summary.freeCount.toString(),
                        ),
                        _ReaderAnalyticsMetric(
                          label: 'Premium',
                          value: summary.premiumCount.toString(),
                        ),
                        _ReaderAnalyticsMetric(
                          label: 'Categories',
                          value: summary.categoryCounts.length.toString(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (summary.latestDocument != null) ...[
                      const Text(
                        'Latest Update',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.update,
                          color: Colors.greenAccent,
                        ),
                        title: Text(
                          summary.latestDocument!.name,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        subtitle: Text(
                          '${summary.latestDocument!.accessLabel} | '
                          '${summary.latestDocument!.category} | '
                          'Updated ${formatVaultDocumentDate(summary.latestDocument!.updatedAt)}',
                          style: const TextStyle(color: Colors.white38),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ] else if (summary.hasDocuments) ...[
                      const Text(
                        'Latest Update',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Upload dates will appear after documents include update metadata.',
                        style: TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 18),
                    ],
                    const Text(
                      'By Category',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!summary.hasDocuments)
                      const Text(
                        'No vault PDFs are loaded yet.',
                        style: TextStyle(color: Colors.white54),
                      )
                    else
                      ...summary.categoryCounts.map(
                        (count) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          hoverColor: Colors.greenAccent.withValues(
                            alpha: 0.08,
                          ),
                          leading: const Icon(
                            Icons.folder_outlined,
                            color: Colors.greenAccent,
                          ),
                          title: Text(
                            count.category,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          subtitle: Text(
                            '${count.freeCount} free | '
                            '${count.premiumCount} premium',
                            style: const TextStyle(color: Colors.white38),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                count.totalCount.toString(),
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.filter_alt_outlined,
                                color: Colors.white38,
                                size: 18,
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              freeDocumentCategoryFilter = count.category;
                              premiumDocumentCategoryFilter = count.category;
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    freeDocumentCategoryFilter = '';
                    premiumDocumentCategoryFilter = '';
                  });
                  Navigator.pop(context);
                },
                child: const Text(
                  'Show All',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.greenAccent),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> showUserAccessOverview() async {
    if (!requireVaultManagerAccess()) return;

    var summaryFuture = userAccessRepository.loadSummary(limit: 100);
    String? busyUserEmail;
    var accessSearchQuery = '';
    UserAccessPlan? accessPlanFilter;
    var countryFilter = '';
    final accessSearchController = TextEditingController();
    final currentUserEmail = UserAccessRepository.emailDocumentId(
      FirebaseAuth.instance.currentUser?.email,
    );

    UserAccessPlan currentPlan(UserAccessRecord user) {
      return userAccessPlanForState(user.access);
    }

    List<UserAccessPlan> availablePlanActions(UserAccessRecord user) {
      final activePlan = currentPlan(user);
      return UserAccessPlan.values
          .where((plan) => plan != activePlan)
          .toList(growable: false);
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> applyPlan(
              UserAccessRecord user,
              UserAccessPlan plan,
            ) async {
              if (user.email == currentUserEmail) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Use another admin account to change your own access.',
                    ),
                  ),
                );
                return;
              }

              setDialogState(() {
                busyUserEmail = user.email;
              });

              try {
                await userAccessRepository.saveAccessPlan(
                  email: user.email,
                  plan: plan,
                  changedByEmail: currentUserEmail,
                  previousPlan: currentPlan(user),
                );

                if (!mounted) return;

                setDialogState(() {
                  summaryFuture = userAccessRepository.loadSummary(limit: 100);
                  busyUserEmail = null;
                });
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${user.email} moved to ${userAccessPlanLabel(plan)} access.',
                    ),
                  ),
                );
                await checkUserRole();
              } catch (error) {
                if (!mounted) return;

                setDialogState(() {
                  busyUserEmail = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Access update failed: $error')),
                );
              }
            }

            Widget accessActions(UserAccessRecord user) {
              final isCurrentUser = user.email == currentUserEmail;
              final isBusy = busyUserEmail == user.email;

              if (isBusy) {
                return const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.greenAccent,
                  ),
                );
              }

              return Wrap(
                spacing: 6,
                children: availablePlanActions(user).map((plan) {
                  return TextButton(
                    onPressed: busyUserEmail != null || isCurrentUser
                        ? null
                        : () => applyPlan(user, plan),
                    style: TextButton.styleFrom(
                      foregroundColor: plan == UserAccessPlan.free
                          ? Colors.orangeAccent
                          : Colors.greenAccent,
                      disabledForegroundColor: Colors.white24,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(userAccessPlanLabel(plan)),
                  );
                }).toList(),
              );
            }

            ChoiceChip planFilterChip({
              required String label,
              required UserAccessPlan? plan,
            }) {
              final selected = accessPlanFilter == plan;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) {
                  setDialogState(() {
                    accessPlanFilter = plan;
                  });
                },
                selectedColor: Colors.greenAccent,
                backgroundColor: const Color(0xFF151821),
                labelStyle: TextStyle(
                  color: selected ? Colors.black : Colors.white70,
                ),
                side: const BorderSide(color: Colors.white24),
              );
            }

            void clearAccessFilters() {
              accessSearchController.clear();
              setDialogState(() {
                accessSearchQuery = '';
                accessPlanFilter = null;
                countryFilter = '';
              });
            }

            Widget accessActiveFilterBar(List<String> labels) {
              if (labels.isEmpty) return const SizedBox.shrink();

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...labels.map(
                    (label) => Chip(
                      label: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: const Color(0xFF151821),
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: clearAccessFilters,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear all'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.greenAccent,
                    ),
                  ),
                ],
              );
            }

            return PointerInterceptor(
              child: AlertDialog(
                backgroundColor: const Color(0xFF0F1117),
                title: const Text(
                  'User Access',
                  style: TextStyle(color: Colors.greenAccent),
                ),
                content: SizedBox(
                  width: 620,
                  child: FutureBuilder<UserAccessSummary>(
                    future: summaryFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(
                          snapshot.error.toString(),
                          style: const TextStyle(color: Colors.redAccent),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.greenAccent,
                            ),
                          ),
                        );
                      }

                      final summary = snapshot.data!;
                      if (!summary.hasUsers) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No user access records were found yet.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      final visibleUsers = summary.filteredUsers(
                        query: accessSearchQuery,
                        plan: accessPlanFilter,
                        country: countryFilter,
                      );
                      final activeFilterLabels = userAccessActiveFilterLabels(
                        query: accessSearchQuery,
                        plan: accessPlanFilter,
                        country: countryFilter,
                      );
                      final hasActiveFilter = hasUserAccessFilters(
                        query: accessSearchQuery,
                        plan: accessPlanFilter,
                        country: countryFilter,
                      );
                      final displayedUsers = visibleUsers
                          .take(userAccessDefaultDisplayLimit)
                          .toList(growable: false);
                      final listLimitMessage = userAccessListLimitMessage(
                        visibleCount: visibleUsers.length,
                      );

                      return SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _ReaderAnalyticsMetric(
                                  label: 'Users',
                                  value: summary.totalCount.toString(),
                                ),
                                _ReaderAnalyticsMetric(
                                  label: 'Admins',
                                  value: summary.adminCount.toString(),
                                ),
                                _ReaderAnalyticsMetric(
                                  label: 'Premium',
                                  value: summary.premiumCount.toString(),
                                ),
                                _ReaderAnalyticsMetric(
                                  label: 'Free',
                                  value: summary.freeCount.toString(),
                                  color: Colors.orangeAccent,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            TextField(
                              controller: accessSearchController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Search users',
                                hintText: 'Email, name, country, or plan',
                                labelStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                hintStyle: const TextStyle(
                                  color: Colors.white38,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Colors.greenAccent,
                                ),
                                suffixIcon: accessSearchQuery.trim().isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search',
                                        icon: const Icon(Icons.clear),
                                        color: Colors.white70,
                                        onPressed: () {
                                          accessSearchController.clear();
                                          setDialogState(() {
                                            accessSearchQuery = '';
                                          });
                                        },
                                      ),
                                enabledBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.greenAccent,
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                setDialogState(() {
                                  accessSearchQuery = value;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                planFilterChip(label: 'All', plan: null),
                                planFilterChip(
                                  label: 'Admin',
                                  plan: UserAccessPlan.admin,
                                ),
                                planFilterChip(
                                  label: 'Premium',
                                  plan: UserAccessPlan.premium,
                                ),
                                planFilterChip(
                                  label: 'Free',
                                  plan: UserAccessPlan.free,
                                ),
                              ],
                            ),
                            if (summary.countryOptions.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                key: ValueKey('access-country-$countryFilter'),
                                initialValue: countryFilter,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF1A1D25),
                                iconEnabledColor: Colors.greenAccent,
                                style: const TextStyle(color: Colors.white70),
                                decoration: const InputDecoration(
                                  labelText: 'Filter by country',
                                  labelStyle: TextStyle(color: Colors.white70),
                                  floatingLabelStyle: TextStyle(
                                    color: Colors.greenAccent,
                                  ),
                                  filled: true,
                                  fillColor: Color(0xFF151821),
                                  border: OutlineInputBorder(),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white24,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.greenAccent,
                                    ),
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: '',
                                    child: Text('All countries'),
                                  ),
                                  ...summary.countryOptions.map(
                                    (country) => DropdownMenuItem<String>(
                                      value: country,
                                      child: Text(country),
                                    ),
                                  ),
                                ],
                                onChanged: (country) {
                                  setDialogState(() {
                                    countryFilter = country ?? '';
                                  });
                                },
                              ),
                            ],
                            if (activeFilterLabels.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              accessActiveFilterBar(activeFilterLabels),
                            ],
                            const SizedBox(height: 14),
                            const Text(
                              'Access Records',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${userAccessFilteredCountLabel(visibleCount: visibleUsers.length, totalCount: summary.totalCount, hasActiveFilter: hasActiveFilter)} users shown',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (visibleUsers.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'No users match this search.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ...displayedUsers.map((user) {
                              final timestamp =
                                  user.updatedAt ?? user.createdAt;

                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  user.access.isAdmin
                                      ? Icons.admin_panel_settings_outlined
                                      : user.access.hasActiveSubscription
                                      ? Icons.workspace_premium_outlined
                                      : Icons.person_outline,
                                  color: user.access.canAccessMainVault
                                      ? Colors.greenAccent
                                      : Colors.orangeAccent,
                                ),
                                title: Text(
                                  user.email.isEmpty
                                      ? 'Unknown user'
                                      : user.email,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                subtitle: Text(
                                  userAccessRecordDetailLabel(
                                    user,
                                    isCurrentUser:
                                        user.email == currentUserEmail,
                                    timestampLabel: formatDashboardTimestamp(
                                      timestamp,
                                    ),
                                  ),
                                  style: const TextStyle(color: Colors.white38),
                                ),
                                trailing: accessActions(user),
                              );
                            }),
                            if (listLimitMessage != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                listLimitMessage,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (summary.hasRecentChanges) ...[
                              const SizedBox(height: 18),
                              const Text(
                                'Recent Access Changes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...summary.recentChanges.map((change) {
                                final previousPlan = change.previousPlan == null
                                    ? 'Unknown'
                                    : userAccessPlanLabel(change.previousPlan!);

                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.manage_history_outlined,
                                    color: Colors.greenAccent,
                                  ),
                                  title: Text(
                                    change.targetEmail.isEmpty
                                        ? 'Unknown user'
                                        : change.targetEmail,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  subtitle: Text(
                                    [
                                      '$previousPlan to ${userAccessPlanLabel(change.nextPlan)}',
                                      if (change.changedByEmail.isNotEmpty)
                                        'by ${change.changedByEmail}',
                                      formatDashboardTimestamp(
                                        change.createdAt,
                                      ),
                                    ].join(' | '),
                                    style: const TextStyle(
                                      color: Colors.white38,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Colors.greenAccent),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(accessSearchController.dispose);
  }

  Future<void> showDeviceAuthorizationOverview() async {
    if (!requireVaultManagerAccess()) return;

    var summaryFuture = deviceAuthorizationRepository.loadSummary(limit: 100);
    String? busyDeviceId;
    var deviceSearchQuery = '';
    UserDeviceStatus? deviceStatusFilter;
    var countryFilter = '';
    final deviceSearchController = TextEditingController();
    final currentUserEmail = UserAccessRepository.emailDocumentId(
      FirebaseAuth.instance.currentUser?.email,
    );

    List<UserDeviceStatus> availableStatusActions(UserDeviceRecord device) {
      return UserDeviceStatus.values
          .where((status) => status != device.status)
          .toList(growable: false);
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> applyDeviceStatus(
              UserDeviceRecord device,
              UserDeviceStatus status,
            ) async {
              setDialogState(() {
                busyDeviceId = device.id;
              });

              try {
                await deviceAuthorizationRepository.saveDeviceStatus(
                  deviceId: device.id,
                  status: status,
                  changedByEmail: currentUserEmail,
                  previousStatus: device.status,
                );

                if (!mounted) return;

                setDialogState(() {
                  summaryFuture = deviceAuthorizationRepository.loadSummary(
                    limit: 100,
                  );
                  busyDeviceId = null;
                });
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${userDeviceRecordTitle(device)} marked ${userDeviceStatusLabel(status)}.',
                    ),
                  ),
                );
              } catch (error) {
                if (!mounted) return;

                setDialogState(() {
                  busyDeviceId = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Device authorization update failed: $error'),
                  ),
                );
              }
            }

            Widget deviceActions(UserDeviceRecord device) {
              final isBusy = busyDeviceId == device.id;

              if (isBusy) {
                return const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.greenAccent,
                  ),
                );
              }

              return Wrap(
                spacing: 6,
                children: availableStatusActions(device).map((status) {
                  return TextButton(
                    onPressed: busyDeviceId != null
                        ? null
                        : () => applyDeviceStatus(device, status),
                    style: TextButton.styleFrom(
                      foregroundColor: status == UserDeviceStatus.blocked
                          ? Colors.orangeAccent
                          : Colors.greenAccent,
                      disabledForegroundColor: Colors.white24,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(userDeviceStatusLabel(status)),
                  );
                }).toList(),
              );
            }

            ChoiceChip statusFilterChip({
              required String label,
              required UserDeviceStatus? status,
            }) {
              final selected = deviceStatusFilter == status;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) {
                  setDialogState(() {
                    deviceStatusFilter = status;
                  });
                },
                selectedColor: Colors.greenAccent,
                backgroundColor: const Color(0xFF151821),
                labelStyle: TextStyle(
                  color: selected ? Colors.black : Colors.white70,
                ),
                side: const BorderSide(color: Colors.white24),
              );
            }

            void clearDeviceFilters() {
              deviceSearchController.clear();
              setDialogState(() {
                deviceSearchQuery = '';
                deviceStatusFilter = null;
                countryFilter = '';
              });
            }

            Widget deviceAuthorizationModeBanner() {
              final isEnforced = userDeviceAuthorizationIsEnforced(
                readerDeviceAuthorizationMode,
              );

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF151821),
                  border: Border.all(
                    color: isEnforced ? Colors.greenAccent : Colors.white24,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isEnforced
                          ? Icons.verified_user_outlined
                          : Icons.visibility_outlined,
                      color: isEnforced
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userDeviceAuthorizationModeTitle(
                              readerDeviceAuthorizationMode,
                            ),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userDeviceAuthorizationModeDescription(
                              readerDeviceAuthorizationMode,
                            ),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget deviceAuthorizationReadinessBanner(
              UserDeviceSummary summary,
            ) {
              final isReady = summary.isReadyForEnforcement;

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF151821),
                  border: Border.all(
                    color: isReady ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isReady
                          ? Icons.check_circle_outline
                          : Icons.pending_actions_outlined,
                      color: isReady ? Colors.greenAccent : Colors.orangeAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userDeviceAuthorizationReadinessTitle(summary),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userDeviceAuthorizationReadinessDescription(
                              summary,
                            ),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget deviceActiveFilterBar(List<String> labels) {
              if (labels.isEmpty) return const SizedBox.shrink();

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...labels.map(
                    (label) => Chip(
                      label: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: const Color(0xFF151821),
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: clearDeviceFilters,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear all'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.greenAccent,
                    ),
                  ),
                ],
              );
            }

            return PointerInterceptor(
              child: AlertDialog(
                backgroundColor: const Color(0xFF0F1117),
                title: const Text(
                  'Device Authorization',
                  style: TextStyle(color: Colors.greenAccent),
                ),
                content: SizedBox(
                  width: 620,
                  child: FutureBuilder<UserDeviceSummary>(
                    future: summaryFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(
                          snapshot.error.toString(),
                          style: const TextStyle(color: Colors.redAccent),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.greenAccent,
                            ),
                          ),
                        );
                      }

                      final summary = snapshot.data!;
                      if (!summary.hasDevices) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            deviceAuthorizationModeBanner(),
                            const SizedBox(height: 10),
                            deviceAuthorizationReadinessBanner(summary),
                            const SizedBox(height: 14),
                            const Text(
                              'No device authorization records were found yet.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        );
                      }

                      final visibleDevices = summary.filteredDevices(
                        query: deviceSearchQuery,
                        status: deviceStatusFilter,
                        country: countryFilter,
                      );
                      final activeFilterLabels = userDeviceActiveFilterLabels(
                        query: deviceSearchQuery,
                        status: deviceStatusFilter,
                        country: countryFilter,
                      );
                      final hasActiveFilter = hasUserDeviceFilters(
                        query: deviceSearchQuery,
                        status: deviceStatusFilter,
                        country: countryFilter,
                      );
                      final displayedDevices = visibleDevices
                          .take(userDeviceDefaultDisplayLimit)
                          .toList(growable: false);
                      final listLimitMessage = userDeviceListLimitMessage(
                        visibleCount: visibleDevices.length,
                      );

                      return SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            deviceAuthorizationModeBanner(),
                            const SizedBox(height: 10),
                            deviceAuthorizationReadinessBanner(summary),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _ReaderAnalyticsMetric(
                                  label: 'Devices',
                                  value: summary.totalCount.toString(),
                                ),
                                _ReaderAnalyticsMetric(
                                  label: 'Pending',
                                  value: summary.pendingCount.toString(),
                                  color: Colors.orangeAccent,
                                ),
                                _ReaderAnalyticsMetric(
                                  label: 'Trusted',
                                  value: summary.trustedCount.toString(),
                                ),
                                _ReaderAnalyticsMetric(
                                  label: 'Blocked',
                                  value: summary.blockedCount.toString(),
                                  color: Colors.redAccent,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            TextField(
                              controller: deviceSearchController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Search devices',
                                hintText: 'Email, device, platform, country',
                                labelStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                hintStyle: const TextStyle(
                                  color: Colors.white38,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Colors.greenAccent,
                                ),
                                suffixIcon: deviceSearchQuery.trim().isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search',
                                        icon: const Icon(Icons.clear),
                                        color: Colors.white70,
                                        onPressed: () {
                                          deviceSearchController.clear();
                                          setDialogState(() {
                                            deviceSearchQuery = '';
                                          });
                                        },
                                      ),
                                enabledBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.greenAccent,
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                setDialogState(() {
                                  deviceSearchQuery = value;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                statusFilterChip(label: 'All', status: null),
                                statusFilterChip(
                                  label: 'Pending',
                                  status: UserDeviceStatus.pending,
                                ),
                                statusFilterChip(
                                  label: 'Trusted',
                                  status: UserDeviceStatus.trusted,
                                ),
                                statusFilterChip(
                                  label: 'Blocked',
                                  status: UserDeviceStatus.blocked,
                                ),
                              ],
                            ),
                            if (summary.countryOptions.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                key: ValueKey('device-country-$countryFilter'),
                                initialValue: countryFilter,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF1A1D25),
                                iconEnabledColor: Colors.greenAccent,
                                style: const TextStyle(color: Colors.white70),
                                decoration: const InputDecoration(
                                  labelText: 'Filter by country',
                                  labelStyle: TextStyle(color: Colors.white70),
                                  floatingLabelStyle: TextStyle(
                                    color: Colors.greenAccent,
                                  ),
                                  filled: true,
                                  fillColor: Color(0xFF151821),
                                  border: OutlineInputBorder(),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white24,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.greenAccent,
                                    ),
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: '',
                                    child: Text('All countries'),
                                  ),
                                  ...summary.countryOptions.map(
                                    (country) => DropdownMenuItem<String>(
                                      value: country,
                                      child: Text(country),
                                    ),
                                  ),
                                ],
                                onChanged: (country) {
                                  setDialogState(() {
                                    countryFilter = country ?? '';
                                  });
                                },
                              ),
                            ],
                            if (activeFilterLabels.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              deviceActiveFilterBar(activeFilterLabels),
                            ],
                            const SizedBox(height: 14),
                            const Text(
                              'Device Records',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${userDeviceFilteredCountLabel(visibleCount: visibleDevices.length, totalCount: summary.totalCount, hasActiveFilter: hasActiveFilter)} devices shown',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (visibleDevices.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'No devices match this search.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ...displayedDevices.map((device) {
                              final timestamp =
                                  device.lastSeenAt ??
                                  device.updatedAt ??
                                  device.createdAt;

                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  switch (device.status) {
                                    UserDeviceStatus.pending =>
                                      Icons.device_unknown_outlined,
                                    UserDeviceStatus.trusted =>
                                      Icons.verified_user_outlined,
                                    UserDeviceStatus.blocked =>
                                      Icons.block_outlined,
                                  },
                                  color: device.isBlocked
                                      ? Colors.redAccent
                                      : device.isTrusted
                                      ? Colors.greenAccent
                                      : Colors.orangeAccent,
                                ),
                                title: Text(
                                  userDeviceRecordTitle(device),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                subtitle: Text(
                                  userDeviceRecordDetailLabel(
                                    device,
                                    timestampLabel: formatDashboardTimestamp(
                                      timestamp,
                                    ),
                                  ),
                                  style: const TextStyle(color: Colors.white38),
                                ),
                                trailing: deviceActions(device),
                              );
                            }),
                            if (listLimitMessage != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                listLimitMessage,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (summary.hasRecentChanges) ...[
                              const SizedBox(height: 18),
                              const Text(
                                'Recent Device Decisions',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...summary.recentChanges.map((change) {
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.manage_history_outlined,
                                    color: Colors.greenAccent,
                                  ),
                                  title: Text(
                                    userDeviceStatusChangeTitle(change),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  subtitle: Text(
                                    userDeviceStatusChangeDetailLabel(
                                      change,
                                      timestampLabel: formatDashboardTimestamp(
                                        change.createdAt,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white38,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Colors.greenAccent),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(deviceSearchController.dispose);
  }

  Future<void> saveUserNote({
    required String pdfTitle,
    required String selectedText,
    required String note,
    required String color,
    required int pageNumber,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email;
    if (userEmail == null || userEmail.isEmpty) return;

    await readerNoteRepository.save(
      ReaderNoteDraft(
        userEmail: userEmail,
        pdfTitle: pdfTitle,
        selectedText: selectedText,
        note: note,
        color: color,
        pageNumber: pageNumber,
      ),
    );
  }

  Future<void> checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    final access = await userAccessRepository.loadForEmail(user?.email);

    if (!mounted) return;

    setState(() {
      userAccess = access;
    });
  }

  bool looksLikePdfFile(Uint8List fileBytes) {
    if (fileBytes.length < 5) return false;

    final headerLength = fileBytes.length < 1024 ? fileBytes.length : 1024;
    final header = String.fromCharCodes(fileBytes.take(headerLength));

    return header.contains('%PDF-');
  }

  bool isSafeVaultPdfFileName(String fileName) {
    final trimmedFileName = fileName.trim();

    if (trimmedFileName.isEmpty) return false;
    if (!trimmedFileName.toLowerCase().endsWith('.pdf')) return false;
    if (trimmedFileName.contains('/') || trimmedFileName.contains(r'\')) {
      return false;
    }

    return !trimmedFileName.codeUnits.any((codeUnit) => codeUnit < 32);
  }

  Future<bool> storageObjectExists(Reference ref) async {
    try {
      await ref.getMetadata();
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        return false;
      }

      rethrow;
    }
  }

  Future<VaultUploadOptions?> chooseVaultUploadOptions() {
    var selectedAccessLevel = 'premium';
    var selectedCategory = vaultDocumentCategories.first;

    return showDialog<VaultUploadOptions>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PointerInterceptor(
              child: AlertDialog(
                backgroundColor: const Color(0xFF0F1117),
                title: const Text(
                  'Classify Upload',
                  style: TextStyle(color: Colors.greenAccent),
                ),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedAccessLevel,
                        dropdownColor: const Color(0xFF1A1D25),
                        iconEnabledColor: Colors.greenAccent,
                        style: const TextStyle(color: Colors.white70),
                        decoration: const InputDecoration(
                          labelText: 'Vault access',
                          labelStyle: TextStyle(color: Colors.white70),
                          floatingLabelStyle: TextStyle(
                            color: Colors.greenAccent,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.greenAccent),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'premium',
                            child: Text('Premium vault'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'free',
                            child: Text('Free access zone'),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedAccessLevel = value ?? 'premium';
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        dropdownColor: const Color(0xFF1A1D25),
                        iconEnabledColor: Colors.greenAccent,
                        style: const TextStyle(color: Colors.white70),
                        decoration: const InputDecoration(
                          labelText: 'Document category',
                          labelStyle: TextStyle(color: Colors.white70),
                          floatingLabelStyle: TextStyle(
                            color: Colors.greenAccent,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.greenAccent),
                          ),
                        ),
                        items: vaultDocumentCategories
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedCategory =
                                value ?? vaultDocumentCategories.first;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        VaultUploadOptions(
                          accessLevel: selectedAccessLevel,
                          category: selectedCategory,
                        ),
                      );
                    },
                    child: const Text(
                      'Continue',
                      style: TextStyle(color: Colors.greenAccent),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> uploadPDF() async {
    if (!requireVaultManagerAccess()) return;

    try {
      final uploadOptions = await chooseVaultUploadOptions();
      if (uploadOptions == null) return;

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null) {
        final fileBytes = result.files.first.bytes;
        final fileName = result.files.first.name;

        if (!isSafeVaultPdfFileName(fileName)) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Use a simple PDF file name ending in .pdf before uploading.',
              ),
            ),
          );
          return;
        }

        if (fileBytes == null) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read the selected PDF file.'),
            ),
          );
          return;
        }

        if (!looksLikePdfFile(fileBytes)) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only valid PDF files can be uploaded.'),
            ),
          );
          return;
        }

        final uploadProfile = uploadOptions.profile;
        final storagePath = '${uploadProfile.storageFolder}/$fileName';
        final ref = FirebaseStorage.instance.ref(storagePath);

        final alreadyExists = await storageObjectExists(ref);

        if (alreadyExists) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'A protected PDF with this name already exists. Rename the file before uploading.',
              ),
            ),
          );
          return;
        }

        await ref.putData(
          fileBytes,
          SettableMetadata(
            contentType: 'application/pdf',
            customMetadata: uploadProfile.toStorageMetadata(
              uploadedBy: FirebaseAuth.instance.currentUser?.email ?? '',
              originalFileName: fileName,
            ),
          ),
        );

        await indexPdfForSearch(
          pdfBytes: fileBytes,
          pdfTitle: fileName,
          accessLevel: uploadProfile.accessLevel,
          storagePath: storagePath,
          category: uploadProfile.category,
        );

        await loadPDFs();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fileName uploaded and indexed successfully'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> indexPdfForSearch({
    required Uint8List pdfBytes,
    required String pdfTitle,
    required String accessLevel,
    required String storagePath,
    String category = 'General',
    String? pdfUrl,
    bool replaceExisting = false,
  }) async {
    if (replaceExisting) {
      await clearSearchIndexForStoragePath(storagePath);
    }

    final normalizedAccessLevel = accessLevel.trim().toLowerCase();
    final normalizedCategory = normalizeVaultDocumentCategory(category);
    final documentProfile = VaultDocumentProfile.forAccessLevel(
      accessLevel: normalizedAccessLevel,
      category: normalizedCategory,
    );
    final titleKeywords = vaultSearchTerms(pdfTitle);
    final document = PdfDocument(inputBytes: pdfBytes);

    try {
      final extractor = PdfTextExtractor(document);
      final searchIndexRows = <Map<String, dynamic>>[];

      for (int i = 0; i < document.pages.count; i++) {
        final text = extractor.extractText(startPageIndex: i, endPageIndex: i);

        if (text.trim().isEmpty) continue;

        final lowerText = text.toLowerCase();
        final searchIndexData = <String, dynamic>{
          'pdfTitle': pdfTitle,
          'storagePath': storagePath,
          'pageNumber': i + 1,
          'text': text.length > 1200 ? text.substring(0, 1200) : text,
          'textLower': lowerText,
          'keywords': vaultSearchTerms(text).take(300).toList(),
          'titleKeywords': titleKeywords,
          ...documentProfile.toDocumentMap(),
          'createdAt': FieldValue.serverTimestamp(),
        };

        if (documentProfile.accessLevel == 'free' && pdfUrl != null) {
          searchIndexData['pdfUrl'] = pdfUrl;
        }

        searchIndexRows.add(searchIndexData);
      }

      final searchIndexCollection = FirebaseFirestore.instance.collection(
        'pdf_search_index',
      );
      for (final chunk in chunkVaultSearchIndexRows(searchIndexRows)) {
        final batch = FirebaseFirestore.instance.batch();
        for (final row in chunk) {
          batch.set(searchIndexCollection.doc(), row);
        }
        await batch.commit();
      }
    } finally {
      document.dispose();
    }
  }

  Future<int> clearSearchIndexForStoragePath(String storagePath) async {
    final normalizedStoragePath = storagePath.trim();
    if (normalizedStoragePath.isEmpty) return 0;

    final existing = await FirebaseFirestore.instance
        .collection('pdf_search_index')
        .where('storagePath', isEqualTo: normalizedStoragePath)
        .get();

    var deletedCount = 0;
    for (var i = 0; i < existing.docs.length; i += 450) {
      final batch = FirebaseFirestore.instance.batch();
      final chunk = existing.docs.skip(i).take(450);
      for (final doc in chunk) {
        batch.delete(doc.reference);
        deletedCount++;
      }
      await batch.commit();
    }

    return deletedCount;
  }

  Future<void> indexExistingVaultPdfs() async {
    if (!requireVaultManagerAccess()) return;

    try {
      Future<VaultDocumentIndexingSummary> indexFolder(
        String folderName,
        String level,
      ) async {
        final result = await FirebaseStorage.instance.ref(folderName).listAll();
        var summary = const VaultDocumentIndexingSummary();

        for (final item in result.items) {
          final existing = await FirebaseFirestore.instance
              .collection('pdf_search_index')
              .where('storagePath', isEqualTo: item.fullPath)
              .limit(1)
              .get();
          final hasExistingIndex = existing.docs.isNotEmpty;

          FullMetadata? metadata;
          try {
            metadata = await item.getMetadata();
          } catch (_) {
            metadata = null;
          }
          final documentMetadata = VaultDocumentMetadata.fromStorageMetadata(
            metadata?.customMetadata,
            fallbackAccessLevel: level,
          );

          final url = await item.getDownloadURL();
          final response = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 25));

          await indexPdfForSearch(
            pdfBytes: response.bodyBytes,
            pdfUrl: url,
            pdfTitle: item.name,
            accessLevel: documentMetadata.accessLevel,
            storagePath: item.fullPath,
            category: documentMetadata.category,
            replaceExisting: hasExistingIndex,
          );
          summary = hasExistingIndex
              ? summary.addRefreshed()
              : summary.addIndexed();
        }

        return summary;
      }

      final summary = (await indexFolder(
        'free_pdfs',
        'free',
      )).merge(await indexFolder('vault_pdfs', 'premium'));

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(summary.displayMessage)));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Indexing failed: $e')));
    }
  }

  Future<Map<String, dynamic>> loadVaultPdfListItem(
    Reference item, {
    required String fallbackAccessLevel,
  }) async {
    FullMetadata? metadata;
    try {
      metadata = await item.getMetadata();
    } catch (_) {
      metadata = null;
    }

    final documentMetadata = VaultDocumentMetadata.fromStorageMetadata(
      metadata?.customMetadata,
      fallbackAccessLevel: fallbackAccessLevel,
      sizeBytes: metadata?.size,
      updatedAt: metadata?.updated,
    );

    return {
      'name': item.name,
      'storagePath': item.fullPath,
      ...documentMetadata.toDocumentMap(),
    };
  }

  Future<void> loadPDFs() async {
    setState(() {
      isLoading = true;
      pdfLoadError = null;
    });

    try {
      final freeResult = await FirebaseStorage.instance
          .ref('free_pdfs')
          .listAll();

      final loadedFreeFiles = <Map<String, dynamic>>[];
      final loadedPremiumFiles = <Map<String, dynamic>>[];

      for (var item in freeResult.items) {
        loadedFreeFiles.add(
          await loadVaultPdfListItem(item, fallbackAccessLevel: 'free'),
        );
      }

      try {
        final premiumResult = await FirebaseStorage.instance
            .ref('vault_pdfs')
            .listAll();
        for (var item in premiumResult.items) {
          final document = await loadVaultPdfListItem(
            item,
            fallbackAccessLevel: 'premium',
          );

          if (document['accessLevel'] == 'free') {
            loadedFreeFiles.add(document);
          } else if (userAccess.canAccessMainVault) {
            loadedPremiumFiles.add(document);
          }
        }
      } catch (_) {
        if (userAccess.canAccessMainVault) {
          rethrow;
        }
      }

      if (!mounted) return;

      setState(() {
        freePdfFiles = sortVaultDocumentsForDisplay(loadedFreeFiles);
        premiumPdfFiles = sortVaultDocumentsForDisplay(loadedPremiumFiles);
        pdfLoadError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        pdfLoadError = 'Could not load vault PDFs. Please try again.';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  Future<String?> resolveSearchResultPdfUrl(
    Map<String, dynamic> searchResult,
  ) async {
    final storagePath = searchResult['storagePath']?.toString() ?? '';

    if (storagePath.trim().isNotEmpty) {
      try {
        return await FirebaseStorage.instance.ref(storagePath).getDownloadURL();
      } catch (e) {
        if (!mounted) return null;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open this PDF: $e')));
        return null;
      }
    }

    final legacyPdfUrl = searchResult['pdfUrl']?.toString() ?? '';

    if (legacyPdfUrl.trim().isNotEmpty) {
      return legacyPdfUrl;
    }

    if (!mounted) return null;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This search result is missing its document link.'),
      ),
    );

    return null;
  }

  String vaultDocumentAdminValue(
    Map<String, dynamic> document,
    String key, {
    String fallback = 'Not set',
  }) {
    final value = document[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  Widget buildVaultDocumentAdminDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? 'Not set' : value,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String vaultDocumentAdminAccessLevel(
    Map<String, dynamic> document, {
    required String accessLabel,
  }) {
    final fallbackAccessLevel = accessLabel.toLowerCase().contains('free')
        ? 'free'
        : 'premium';
    return normalizeVaultAccessLevel(
      document['accessLevel']?.toString(),
      fallback: fallbackAccessLevel,
    );
  }

  VaultDocumentProfile vaultDocumentAdminProfile(
    Map<String, dynamic> document, {
    required String accessLabel,
  }) {
    return VaultDocumentProfile.forAccessLevel(
      accessLevel: vaultDocumentAdminAccessLevel(
        document,
        accessLabel: accessLabel,
      ),
      category: normalizeVaultDocumentCategory(
        document['category']?.toString(),
      ),
    );
  }

  bool vaultDocumentHasCurrentProfile(
    Map<String, dynamic> document, {
    required String accessLabel,
  }) {
    final profile = vaultDocumentAdminProfile(
      document,
      accessLabel: accessLabel,
    );

    return vaultDocumentAdminValue(document, 'schemaVersion') ==
            profile.schemaVersion &&
        vaultDocumentAdminValue(document, 'accessLevel') ==
            profile.accessLevel &&
        normalizeVaultDocumentCategory(document['category']?.toString()) ==
            profile.category &&
        vaultDocumentAdminValue(document, 'readerMode') == profile.readerMode &&
        vaultDocumentAdminValue(document, 'deliveryMode') ==
            profile.deliveryMode &&
        vaultDocumentAdminValue(document, 'protectionMode') ==
            profile.protectionMode &&
        vaultDocumentAdminValue(document, 'searchMode') == profile.searchMode;
  }

  Future<bool> upgradeVaultDocumentProfileMetadata(
    Map<String, dynamic> document, {
    required String accessLabel,
  }) async {
    if (!requireVaultManagerAccess()) return false;

    final storagePath = vaultDocumentAdminValue(
      document,
      'storagePath',
      fallback: '',
    );
    if (storagePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This document is missing its storage path.'),
        ),
      );
      return false;
    }

    try {
      final ref = FirebaseStorage.instance.ref(storagePath);
      final metadata = await ref.getMetadata();
      final existingCustomMetadata = Map<String, String>.from(
        metadata.customMetadata ?? const <String, String>{},
      );
      final profile = vaultDocumentAdminProfile(
        document,
        accessLabel: accessLabel,
      );
      final documentName = vaultDocumentAdminValue(document, 'name');
      final nextCustomMetadata =
          Map<String, String>.from(existingCustomMetadata)..addAll(
            profile.toStorageMetadata(
              uploadedBy:
                  existingCustomMetadata['uploadedBy'] ??
                  FirebaseAuth.instance.currentUser?.email ??
                  '',
              originalFileName:
                  existingCustomMetadata['originalFileName'] ?? documentName,
            ),
          );

      await ref.updateMetadata(
        SettableMetadata(customMetadata: nextCustomMetadata),
      );
      await loadPDFs();

      if (!mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document profile metadata upgraded.')),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upgrade this document: $e')),
      );
      return false;
    }
  }

  Future<bool> updateVaultDocumentCategory(
    Map<String, dynamic> document, {
    required String accessLabel,
    required String category,
  }) async {
    if (!requireVaultManagerAccess()) return false;

    final storagePath = vaultDocumentAdminValue(
      document,
      'storagePath',
      fallback: '',
    );
    if (storagePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This document is missing its storage path.'),
        ),
      );
      return false;
    }

    final nextCategory = normalizeVaultDocumentCategory(category);
    final currentCategory = normalizeVaultDocumentCategory(
      document['category']?.toString(),
    );
    if (nextCategory == currentCategory) return true;

    try {
      final ref = FirebaseStorage.instance.ref(storagePath);
      final metadata = await ref.getMetadata();
      final existingCustomMetadata = Map<String, String>.from(
        metadata.customMetadata ?? const <String, String>{},
      );
      final accessLevel = vaultDocumentAdminAccessLevel(
        document,
        accessLabel: accessLabel,
      );
      final profile = VaultDocumentProfile.forAccessLevel(
        accessLevel: accessLevel,
        category: nextCategory,
      );
      final documentName = vaultDocumentAdminValue(document, 'name');
      final nextCustomMetadata =
          Map<String, String>.from(existingCustomMetadata)..addAll(
            profile.toStorageMetadata(
              uploadedBy:
                  existingCustomMetadata['uploadedBy'] ??
                  FirebaseAuth.instance.currentUser?.email ??
                  '',
              originalFileName:
                  existingCustomMetadata['originalFileName'] ?? documentName,
            ),
          );

      await ref.updateMetadata(
        SettableMetadata(customMetadata: nextCustomMetadata),
      );

      final updatedDocument = Map<String, dynamic>.from(document)
        ..addAll(profile.toDocumentMap());
      final indexRefreshed = await refreshVaultDocumentSearchIndex(
        updatedDocument,
        accessLabel: accessLabel,
        showSuccessMessage: false,
      );
      if (!indexRefreshed) return false;

      await loadPDFs();

      if (!mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Document category updated to $nextCategory.')),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update this document: $e')),
      );
      return false;
    }
  }

  Future<bool> refreshVaultDocumentSearchIndex(
    Map<String, dynamic> document, {
    required String accessLabel,
    bool showSuccessMessage = true,
  }) async {
    if (!requireVaultManagerAccess()) return false;

    final storagePath = vaultDocumentAdminValue(
      document,
      'storagePath',
      fallback: '',
    );
    if (storagePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This document is missing its storage path.'),
        ),
      );
      return false;
    }

    try {
      final pdfUrl = await resolveSearchResultPdfUrl(document);
      if (pdfUrl == null) return false;

      final response = await http
          .get(Uri.parse(pdfUrl))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode >= 400) {
        throw Exception('The PDF could not be downloaded for indexing.');
      }

      final accessLevel = vaultDocumentAdminAccessLevel(
        document,
        accessLabel: accessLabel,
      );
      final category = normalizeVaultDocumentCategory(
        document['category']?.toString(),
      );

      await indexPdfForSearch(
        pdfBytes: response.bodyBytes,
        pdfUrl: accessLevel == 'free' ? pdfUrl : null,
        pdfTitle: vaultDocumentAdminValue(document, 'name'),
        accessLevel: accessLevel,
        storagePath: storagePath,
        category: category,
        replaceExisting: true,
      );

      if (!mounted) return true;

      if (showSuccessMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document search index refreshed.')),
        );
      }
      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not refresh this document: $e')),
      );
      return false;
    }
  }

  Future<void> showVaultDocumentAdminDialog(
    Map<String, dynamic> document, {
    required String accessLabel,
  }) async {
    if (!requireVaultManagerAccess()) return;

    var isRefreshing = false;
    var isUpgrading = false;
    var isSavingCategory = false;
    var selectedCategory = normalizeVaultDocumentCategory(
      document['category']?.toString(),
    );
    final needsProfileUpgrade = !vaultDocumentHasCurrentProfile(
      document,
      accessLabel: accessLabel,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isBusy = isRefreshing || isUpgrading || isSavingCategory;
            final currentCategory = normalizeVaultDocumentCategory(
              document['category']?.toString(),
            );
            final categoryChanged = selectedCategory != currentCategory;

            return AlertDialog(
              backgroundColor: const Color(0xFF10131A),
              title: const Text(
                'Manage document',
                style: TextStyle(color: Colors.greenAccent),
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        vaultDocumentAdminValue(document, 'name'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white12),
                      buildVaultDocumentAdminDetail(
                        'Profile',
                        needsProfileUpgrade
                            ? 'Legacy metadata - upgrade available'
                            : 'Current metadata',
                      ),
                      buildVaultDocumentAdminDetail('Access', accessLabel),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        dropdownColor: const Color(0xFF1A1D25),
                        iconEnabledColor: Colors.greenAccent,
                        style: const TextStyle(color: Colors.white70),
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          labelStyle: TextStyle(color: Colors.white70),
                          floatingLabelStyle: TextStyle(
                            color: Colors.greenAccent,
                          ),
                          filled: true,
                          fillColor: Color(0xFF151821),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                        ),
                        items: vaultDocumentCategories
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: isBusy
                            ? null
                            : (category) {
                                if (category == null) return;
                                setDialogState(() {
                                  selectedCategory =
                                      normalizeVaultDocumentCategory(category);
                                });
                              },
                      ),
                      if (categoryChanged) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: isBusy
                                ? null
                                : () async {
                                    setDialogState(() {
                                      isSavingCategory = true;
                                    });
                                    final updated =
                                        await updateVaultDocumentCategory(
                                          document,
                                          accessLabel: accessLabel,
                                          category: selectedCategory,
                                        );
                                    if (!context.mounted) return;
                                    setDialogState(() {
                                      isSavingCategory = false;
                                    });
                                    if (updated && dialogContext.mounted) {
                                      Navigator.of(dialogContext).pop();
                                    }
                                  },
                            icon: isSavingCategory
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.greenAccent,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(
                              isSavingCategory
                                  ? 'Saving category...'
                                  : 'Save category',
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      buildVaultDocumentAdminDetail(
                        'Reader',
                        vaultDocumentAdminValue(document, 'readerMode'),
                      ),
                      buildVaultDocumentAdminDetail(
                        'Protection',
                        vaultDocumentAdminValue(document, 'protectionMode'),
                      ),
                      buildVaultDocumentAdminDetail(
                        'Delivery',
                        vaultDocumentAdminValue(document, 'deliveryMode'),
                      ),
                      buildVaultDocumentAdminDetail(
                        'Search',
                        vaultDocumentAdminValue(document, 'searchMode'),
                      ),
                      buildVaultDocumentAdminDetail(
                        'Schema',
                        vaultDocumentAdminValue(document, 'schemaVersion'),
                      ),
                      buildVaultDocumentAdminDetail(
                        'Size',
                        formatVaultDocumentSize(document['sizeBytes'] as num?),
                      ),
                      buildVaultDocumentAdminDetail(
                        'Updated',
                        formatVaultDocumentDate(
                          document['updatedAt'] is DateTime
                              ? document['updatedAt'] as DateTime
                              : null,
                        ),
                      ),
                      buildVaultDocumentAdminDetail(
                        'Storage',
                        vaultDocumentAdminValue(document, 'storagePath'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isBusy
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                if (needsProfileUpgrade)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.greenAccent,
                      side: const BorderSide(color: Colors.greenAccent),
                    ),
                    onPressed: isBusy
                        ? null
                        : () async {
                            setDialogState(() {
                              isUpgrading = true;
                            });
                            final upgraded =
                                await upgradeVaultDocumentProfileMetadata(
                                  document,
                                  accessLabel: accessLabel,
                                );
                            if (!context.mounted) return;
                            setDialogState(() {
                              isUpgrading = false;
                            });
                            if (upgraded && dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          },
                    icon: isUpgrading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.greenAccent,
                            ),
                          )
                        : const Icon(Icons.upgrade),
                    label: Text(
                      isUpgrading ? 'Upgrading...' : 'Upgrade profile',
                    ),
                  ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: isBusy
                      ? null
                      : () async {
                          setDialogState(() {
                            isRefreshing = true;
                          });
                          final refreshed =
                              await refreshVaultDocumentSearchIndex(
                                document,
                                accessLabel: accessLabel,
                              );
                          if (!context.mounted) return;
                          setDialogState(() {
                            isRefreshing = false;
                          });
                          if (refreshed && dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                  icon: isRefreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.manage_search),
                  label: Text(
                    isRefreshing ? 'Refreshing...' : 'Refresh search index',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> globalSearch() async {
    final keywordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F1117),

          title: const Text(
            'Global Vault Search',
            style: TextStyle(color: Colors.greenAccent),
          ),

          content: TextField(
            controller: keywordController,
            style: const TextStyle(color: Colors.white),

            decoration: const InputDecoration(
              hintText: 'Search all vault PDFs...',
              hintStyle: TextStyle(color: Colors.white54),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                final keyword = keywordController.text.trim();

                if (keyword.isEmpty) return;
                if (vaultPrimarySearchTerm(keyword).isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a searchable word.')),
                  );
                  return;
                }

                Navigator.pop(context);

                showGlobalSearchResults(keyword);
              },

              child: const Text(
                'Search',
                style: TextStyle(color: Colors.greenAccent),
              ),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: const Text(
                'Close',
                style: TextStyle(color: Colors.greenAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  List<TextSpan> highlightSearchText(String text, String keyword) {
    final searchTerms = vaultSearchTerms(keyword);
    final fallbackTerm = keyword.trim().toLowerCase();
    final terms = searchTerms.isEmpty && fallbackTerm.isNotEmpty
        ? [fallbackTerm]
        : searchTerms;

    if (terms.isEmpty) {
      return [
        TextSpan(
          text: text,
          style: const TextStyle(color: Colors.white70),
        ),
      ];
    }

    final lowerText = text.toLowerCase();
    final spans = <TextSpan>[];

    int start = 0;

    while (true) {
      var index = -1;
      var matchedTerm = '';

      for (final term in terms) {
        final termIndex = lowerText.indexOf(term, start);
        if (termIndex < 0) continue;
        if (index < 0 ||
            termIndex < index ||
            (termIndex == index && term.length > matchedTerm.length)) {
          index = termIndex;
          matchedTerm = term;
        }
      }

      if (index == -1) {
        spans.add(
          TextSpan(
            text: text.substring(start),
            style: const TextStyle(color: Colors.white70),
          ),
        );
        break;
      }

      if (index > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, index),
            style: const TextStyle(color: Colors.white70),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + matchedTerm.length),
          style: const TextStyle(
            color: Colors.yellow,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + matchedTerm.length;
    }

    return spans;
  }

  Future<void> showGlobalSearchResults(String keyword) async {
    final searchTerm = vaultPrimarySearchTerm(keyword);
    final searchTerms = vaultSearchQueryTerms(keyword);
    String accessFilter = 'all';
    String categoryFilter = '';

    showDialog(
      context: context,
      builder: (resultContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F1117),

              title: Text(
                'Vault Results for "$keyword"',
                style: const TextStyle(color: Colors.greenAccent),
              ),

              contentPadding: const EdgeInsets.all(20),

              content: SizedBox(
                width: 500,
                height: 500,

                child: Column(
                  children: [
                    Wrap(
                      spacing: 10,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: accessFilter == 'all',
                          onSelected: (_) {
                            setState(() {
                              accessFilter = 'all';
                              categoryFilter = '';
                            });
                          },
                        ),

                        ChoiceChip(
                          label: const Text('Free'),
                          selected: accessFilter == 'free',
                          onSelected: (_) {
                            setState(() {
                              accessFilter = 'free';
                              categoryFilter = '';
                            });
                          },
                        ),

                        ChoiceChip(
                          label: const Text('Premium'),
                          selected: accessFilter == 'premium',
                          onSelected: (_) {
                            setState(() {
                              accessFilter = 'premium';
                              categoryFilter = '';
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    Expanded(
                      child: FutureBuilder<List<QuerySnapshot>>(
                        future: Future.wait([
                          for (final term in searchTerms) ...[
                            FirebaseFirestore.instance
                                .collection('pdf_search_index')
                                .where('keywords', arrayContains: term)
                                .limit(30)
                                .get(),
                            FirebaseFirestore.instance
                                .collection('pdf_search_index')
                                .where('titleKeywords', arrayContains: term)
                                .limit(30)
                                .get(),
                          ],
                        ]),

                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Center(
                              child: Text(
                                'Vault search could not load results right now.',
                                style: TextStyle(color: Colors.redAccent),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docsById =
                              <String, QueryDocumentSnapshot<Object?>>{};
                          for (final result in snapshot.data!) {
                            for (final doc in result.docs) {
                              docsById[doc.id] = doc;
                            }
                          }

                          final docs = docsById.values.toList();

                          List<QueryDocumentSnapshot> filteredDocs = docs.where(
                            (doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final titleKeywords = data['titleKeywords'];
                              final hasIndexedTitleMatch =
                                  titleKeywords is Iterable &&
                                  vaultIndexedTermsMatchQuery(
                                    titleKeywords,
                                    keyword,
                                  );
                              final hasLegacyTitleMatch =
                                  titleKeywords == null &&
                                  vaultTextMatchesAnySearchTerm(
                                    data['pdfTitle']?.toString() ?? '',
                                    keyword,
                                  );
                              final hasPageMatch =
                                  data['keywords'] is Iterable &&
                                  vaultIndexedTermsMatchQuery(
                                    data['keywords'] as Iterable,
                                    keyword,
                                  );

                              if (!hasPageMatch &&
                                  !hasIndexedTitleMatch &&
                                  !hasLegacyTitleMatch) {
                                return false;
                              }

                              final documentAccessLevel =
                                  data['accessLevel']?.toString() ?? 'free';

                              return userAccess.canOpenPdfWithAccessLevel(
                                documentAccessLevel,
                              );
                            },
                          ).toList();

                          if (accessFilter == 'free') {
                            filteredDocs = filteredDocs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;

                              return (data['accessLevel'] ?? 'free') == 'free';
                            }).toList();
                          }

                          if (accessFilter == 'premium') {
                            filteredDocs = filteredDocs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;

                              return (data['accessLevel'] ?? 'free') ==
                                  'premium';
                            }).toList();
                          }

                          final accessibleMatchCount = filteredDocs.length;

                          filteredDocs.sort((left, right) {
                            final leftData =
                                left.data() as Map<String, dynamic>;
                            final rightData =
                                right.data() as Map<String, dynamic>;
                            final leftScore = vaultSearchMatchScore(
                              query: keyword,
                              title: leftData['pdfTitle']?.toString() ?? '',
                              text: leftData['text']?.toString() ?? '',
                              pageKeywords: leftData['keywords'] is Iterable
                                  ? leftData['keywords'] as Iterable
                                  : const [],
                              titleKeywords:
                                  leftData['titleKeywords'] is Iterable
                                  ? leftData['titleKeywords'] as Iterable
                                  : const [],
                            );
                            final rightScore = vaultSearchMatchScore(
                              query: keyword,
                              title: rightData['pdfTitle']?.toString() ?? '',
                              text: rightData['text']?.toString() ?? '',
                              pageKeywords: rightData['keywords'] is Iterable
                                  ? rightData['keywords'] as Iterable
                                  : const [],
                              titleKeywords:
                                  rightData['titleKeywords'] is Iterable
                                  ? rightData['titleKeywords'] as Iterable
                                  : const [],
                            );
                            final scoreComparison = rightScore.compareTo(
                              leftScore,
                            );
                            if (scoreComparison != 0) return scoreComparison;

                            final titleComparison =
                                (leftData['pdfTitle']?.toString() ?? '')
                                    .compareTo(
                                      rightData['pdfTitle']?.toString() ?? '',
                                    );
                            if (titleComparison != 0) return titleComparison;

                            final leftPage = leftData['pageNumber'] is int
                                ? leftData['pageNumber'] as int
                                : int.tryParse(
                                        leftData['pageNumber'].toString(),
                                      ) ??
                                      0;
                            final rightPage = rightData['pageNumber'] is int
                                ? rightData['pageNumber'] as int
                                : int.tryParse(
                                        rightData['pageNumber'].toString(),
                                      ) ??
                                      0;

                            return leftPage.compareTo(rightPage);
                          });

                          final categoryOptions = vaultDocumentCategoryOptions(
                            filteredDocs.map(
                              (doc) => doc.data() as Map<String, dynamic>,
                            ),
                          );
                          final safeCategoryFilter =
                              categoryOptions.contains(categoryFilter)
                              ? categoryFilter
                              : '';

                          if (safeCategoryFilter.isNotEmpty) {
                            filteredDocs = filteredDocs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;

                              return normalizeVaultDocumentCategory(
                                    data['category']?.toString(),
                                  ) ==
                                  safeCategoryFilter;
                            }).toList();
                          }

                          return Column(
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${vaultSearchTermsLabel(keyword)} | '
                                  '${vaultSearchResultsLabel(visibleCount: filteredDocs.length, totalCount: accessibleMatchCount)}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (categoryOptions.isNotEmpty) ...[
                                DropdownButtonFormField<String>(
                                  key: ValueKey(
                                    'search-category-$accessFilter-$safeCategoryFilter',
                                  ),
                                  initialValue: safeCategoryFilter,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF1A1D25),
                                  style: const TextStyle(color: Colors.white70),
                                  decoration: const InputDecoration(
                                    labelText: 'Filter by category',
                                    labelStyle: TextStyle(
                                      color: Colors.white70,
                                    ),
                                    floatingLabelStyle: TextStyle(
                                      color: Colors.greenAccent,
                                    ),
                                    filled: true,
                                    fillColor: Color(0xFF151821),
                                    border: OutlineInputBorder(),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white24,
                                      ),
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: '',
                                      child: Text('All categories'),
                                    ),
                                    ...categoryOptions.map(
                                      (category) => DropdownMenuItem<String>(
                                        value: category,
                                        child: Text(category),
                                      ),
                                    ),
                                  ],
                                  onChanged: (category) {
                                    setState(() {
                                      categoryFilter = category ?? '';
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],
                              Expanded(
                                child: filteredDocs.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No matching vault documents found.',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: filteredDocs.length,

                                        itemBuilder: (context, index) {
                                          final data =
                                              filteredDocs[index].data()
                                                  as Map<String, dynamic>;
                                          final snippetKeyword =
                                              vaultBestSnippetKeyword(
                                                data['text']?.toString() ?? '',
                                                keyword,
                                              );
                                          final snippet =
                                              buildVaultSearchSnippet(
                                                data['text']?.toString() ?? '',
                                                snippetKeyword.isEmpty
                                                    ? searchTerm
                                                    : snippetKeyword,
                                              );

                                          return Card(
                                            color: const Color(0xFF1A1D26),

                                            child: ListTile(
                                              leading: Icon(
                                                Icons.picture_as_pdf,
                                                color:
                                                    (data['accessLevel'] ??
                                                            'free') ==
                                                        'premium'
                                                    ? Colors.amber
                                                    : Colors.greenAccent,
                                              ),

                                              title: Text(
                                                data['pdfTitle'] ?? '',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),

                                              subtitle: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,

                                                children: [
                                                  Text(
                                                    'Page ${data['pageNumber']} | ${data['category'] ?? 'General'}',
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                    ),
                                                  ),

                                                  const SizedBox(height: 6),

                                                  RichText(
                                                    maxLines: 3,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    text: TextSpan(
                                                      children:
                                                          highlightSearchText(
                                                            snippet,
                                                            searchTerm,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              onTap: () async {
                                                final resultAccessLevel =
                                                    data['accessLevel']
                                                        ?.toString() ??
                                                    'free';

                                                if (!userAccess
                                                    .canOpenPdfWithAccessLevel(
                                                      resultAccessLevel,
                                                    )) {
                                                  ScaffoldMessenger.of(
                                                    this.context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Subscription required to open this PDF.',
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }

                                                final pdfUrl =
                                                    await resolveSearchResultPdfUrl(
                                                      data,
                                                    );

                                                if (pdfUrl == null) return;
                                                if (!mounted ||
                                                    !resultContext.mounted) {
                                                  return;
                                                }

                                                final pageNumber =
                                                    data['pageNumber'] is int
                                                    ? data['pageNumber'] as int
                                                    : int.tryParse(
                                                            data['pageNumber']
                                                                .toString(),
                                                          ) ??
                                                          0;

                                                Navigator.pop(resultContext);

                                                Navigator.push(
                                                  this.context,
                                                  MaterialPageRoute(
                                                    builder: (context) => PDFViewerScreen(
                                                      pdfUrl: pdfUrl,
                                                      title: data['pdfTitle']
                                                          .toString(),
                                                      initialPage: pageNumber,
                                                      initialSearchQuery:
                                                          keyword,
                                                      accessLevel:
                                                          resultAccessLevel,
                                                      readerMode:
                                                          data['readerMode']
                                                              ?.toString() ??
                                                          '',
                                                      protectionMode:
                                                          data['protectionMode']
                                                              ?.toString() ??
                                                          '',
                                                      openSource:
                                                          'global_search_result',
                                                      storagePath:
                                                          data['storagePath']
                                                              ?.toString() ??
                                                          '',
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                PointerInterceptor(
                  child: TextButton(
                    onPressed: () => Navigator.pop(resultContext),

                    child: const Text(
                      'Close',
                      style: TextStyle(color: Colors.greenAccent),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget buildDocumentCategoryFilter({
    required String filterId,
    required List<Map<String, dynamic>> documents,
    required String selectedCategory,
    required ValueChanged<String> onChanged,
  }) {
    final categories = vaultDocumentCategoryOptions(documents);
    if (categories.isEmpty) return const SizedBox.shrink();
    final safeSelectedCategory = categories.contains(selectedCategory)
        ? selectedCategory
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey(
          'dashboard-document-category-$filterId-$safeSelectedCategory-${categories.join('|')}',
        ),
        initialValue: safeSelectedCategory,
        isExpanded: true,
        dropdownColor: const Color(0xFF1A1D25),
        iconEnabledColor: Colors.greenAccent,
        style: const TextStyle(color: Colors.white70),
        decoration: const InputDecoration(
          labelText: 'Filter by category',
          labelStyle: TextStyle(color: Colors.white70),
          floatingLabelStyle: TextStyle(color: Colors.greenAccent),
          filled: true,
          fillColor: Color(0xFF151821),
          border: OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.greenAccent),
          ),
        ),
        items: [
          const DropdownMenuItem<String>(
            value: '',
            child: Text('All categories'),
          ),
          ...categories.map(
            (category) => DropdownMenuItem<String>(
              value: category,
              child: Text(category),
            ),
          ),
        ],
        onChanged: (category) => onChanged(category ?? ''),
      ),
    );
  }

  Widget buildDashboardDocumentSearch() {
    return TextField(
      controller: dashboardDocumentSearchController,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, color: Colors.greenAccent),
        labelText: 'Filter dashboard PDFs',
        hintText: 'Title, category, date, or path',
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF151821),
        border: const OutlineInputBorder(),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.greenAccent),
        ),
        suffixIcon: dashboardDocumentSearchQuery.trim().isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear PDF filter',
                icon: const Icon(Icons.clear, color: Colors.white70),
                onPressed: () {
                  dashboardDocumentSearchController.clear();
                  setState(() {
                    dashboardDocumentSearchQuery = '';
                  });
                },
              ),
      ),
      onChanged: (value) {
        setState(() {
          dashboardDocumentSearchQuery = value;
        });
      },
    );
  }

  void clearDashboardDocumentFilters() {
    dashboardDocumentSearchController.clear();
    setState(() {
      dashboardDocumentSearchQuery = '';
      freeDocumentCategoryFilter = '';
      premiumDocumentCategoryFilter = '';
    });
  }

  Widget buildDashboardActiveFilterBar(List<String> labels) {
    if (labels.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...labels.map(
            (label) => Chip(
              label: Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              backgroundColor: const Color(0xFF151821),
              side: const BorderSide(color: Colors.white24),
            ),
          ),
          TextButton.icon(
            onPressed: clearDashboardDocumentFilters,
            icon: const Icon(Icons.clear_all, size: 18),
            label: const Text('Clear all'),
            style: TextButton.styleFrom(foregroundColor: Colors.greenAccent),
          ),
        ],
      ),
    );
  }

  Future<void> indexVaultPdfsFromAdminPanel() async {
    if (!requireVaultManagerAccess()) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: Color(0xFF0F1117),
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.greenAccent),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                'Indexing vault PDFs...',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    await indexExistingVaultPdfs();
    if (!mounted) return;

    Navigator.pop(context);
    refreshDashboardAdminOverview();
  }

  Widget buildAdminMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required String detail,
    required Color color,
  }) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151821),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAdminActionButton({
    required IconData icon,
    required String label,
    required String detail,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 230,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: Colors.greenAccent,
          side: const BorderSide(color: Colors.white24),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAdminCategoryBars(VaultDocumentInventorySummary inventory) {
    if (inventory.categoryCounts.isEmpty) {
      return const Text(
        'No categorized documents yet.',
        style: TextStyle(color: Colors.white54),
      );
    }

    final largestCount = inventory.categoryCounts
        .map((count) => count.totalCount)
        .fold<int>(1, math.max);

    return Column(
      children: inventory.categoryCounts.take(6).map((count) {
        final progress = count.totalCount / largestCount;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      count.category,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  Text(
                    '${count.totalCount}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 1).toDouble(),
                  minHeight: 8,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.greenAccent,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget buildAdminActivityList(ReaderActivitySummary activity) {
    if (!activity.hasActivity) {
      return const Text(
        'No reader activity has been recorded yet.',
        style: TextStyle(color: Colors.white54),
      );
    }

    return Column(
      children: activity.recentRecords.take(4).map((record) {
        final title = record.pdfTitle.trim().isEmpty
            ? 'Unknown document'
            : record.pdfTitle.trim();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                record.isBlockedAccess
                    ? Icons.block_outlined
                    : Icons.history_outlined,
                color: record.isBlockedAccess
                    ? Colors.redAccent
                    : Colors.greenAccent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        formatActivityLabel(record),
                        if (record.userEmail.isNotEmpty) record.userEmail,
                        formatDashboardTimestamp(record.createdAt),
                      ].join(' | '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget buildAdminHealthPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAdminVaultHealth(VaultDocumentInventorySummary inventory) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        buildAdminHealthPill(
          icon: Icons.image_outlined,
          label: 'Image reader',
          value: '${inventory.protectedImageCount}/${inventory.totalCount}',
          color: Colors.greenAccent,
        ),
        buildAdminHealthPill(
          icon: Icons.manage_search,
          label: 'Search ready',
          value: '${inventory.fullTextSearchCount}/${inventory.totalCount}',
          color: inventory.searchPendingCount == 0
              ? Colors.lightBlueAccent
              : Colors.orangeAccent,
        ),
        buildAdminHealthPill(
          icon: Icons.schedule_outlined,
          label: 'Missing dates',
          value: inventory.missingDateCount.toString(),
          color: inventory.missingDateCount == 0
              ? Colors.greenAccent
              : Colors.orangeAccent,
        ),
        buildAdminHealthPill(
          icon: Icons.picture_as_pdf_outlined,
          label: 'Standard reader',
          value: inventory.standardReaderCount.toString(),
          color: Colors.white54,
        ),
      ],
    );
  }

  Widget buildAdminRecentDocuments(VaultDocumentInventorySummary inventory) {
    if (!inventory.hasDocuments) {
      return const Text(
        'No vault documents have been uploaded yet.',
        style: TextStyle(color: Colors.white54),
      );
    }

    if (inventory.recentDocuments.isEmpty) {
      return const Text(
        'Recent uploads will appear after documents include update metadata.',
        style: TextStyle(color: Colors.white54),
      );
    }

    return Column(
      children: inventory.recentDocuments.take(4).map((document) {
        final isFree = document.accessLevel == 'free';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isFree
                    ? Icons.picture_as_pdf_outlined
                    : Icons.security_outlined,
                color: isFree ? Colors.orangeAccent : Colors.greenAccent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${document.accessLabel} | ${document.category} | '
                      'Updated ${formatVaultDocumentDate(document.updatedAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _pluralize(int count, String singular, String plural) {
    return '$count ${count == 1 ? singular : plural}';
  }

  Color adminAttentionColor(_AdminAttentionTone tone) {
    return switch (tone) {
      _AdminAttentionTone.danger => Colors.redAccent,
      _AdminAttentionTone.warning => Colors.orangeAccent,
      _AdminAttentionTone.info => Colors.lightBlueAccent,
      _AdminAttentionTone.success => Colors.greenAccent,
    };
  }

  List<_AdminAttentionItem> adminAttentionItems({
    required VaultDocumentInventorySummary inventory,
    _DashboardAdminOverview? overview,
  }) {
    final items = <_AdminAttentionItem>[];

    if (!inventory.hasDocuments) {
      items.add(
        _AdminAttentionItem(
          icon: Icons.upload_file,
          title: 'Vault has no documents yet',
          detail: 'Upload the first profiled PDF to start building the vault.',
          tone: _AdminAttentionTone.info,
          actionLabel: 'Upload',
          onPressed: uploadPDF,
        ),
      );
    }

    if (inventory.searchPendingCount > 0) {
      items.add(
        _AdminAttentionItem(
          icon: Icons.manage_search,
          title: 'Search readiness pending',
          detail:
              '${_pluralize(inventory.searchPendingCount, 'document needs', 'documents need')} a refreshed search profile.',
          tone: _AdminAttentionTone.warning,
          actionLabel: 'Refresh index',
          onPressed: indexVaultPdfsFromAdminPanel,
        ),
      );
    }

    if (inventory.missingDateCount > 0) {
      items.add(
        _AdminAttentionItem(
          icon: Icons.schedule_outlined,
          title: 'Upload dates incomplete',
          detail:
              '${_pluralize(inventory.missingDateCount, 'document is', 'documents are')} missing update metadata for recent activity tracking.',
          tone: _AdminAttentionTone.info,
          actionLabel: 'Inventory',
          onPressed: showVaultInventory,
        ),
      );
    }

    if (inventory.premiumCount > inventory.protectedImageCount) {
      final standardPremiumCount =
          inventory.premiumCount - inventory.protectedImageCount;
      items.add(
        _AdminAttentionItem(
          icon: Icons.security_outlined,
          title: 'Protected reader coverage',
          detail:
              '${_pluralize(standardPremiumCount, 'protected PDF may need', 'protected PDFs may need')} image-reader metadata review.',
          tone: _AdminAttentionTone.warning,
          actionLabel: 'Inventory',
          onPressed: showVaultInventory,
        ),
      );
    }

    if (overview == null) return items;

    if (overview.devices.pendingCount > 0) {
      items.add(
        _AdminAttentionItem(
          icon: Icons.important_devices_outlined,
          title: 'Pending device decisions',
          detail:
              '${_pluralize(overview.devices.pendingCount, 'device needs', 'devices need')} trust or block review before strict enforcement.',
          tone: _AdminAttentionTone.danger,
          actionLabel: 'Review devices',
          onPressed: showDeviceAuthorizationOverview,
        ),
      );
    }

    if (overview.devices.blockedCount > 0) {
      items.add(
        _AdminAttentionItem(
          icon: Icons.block_outlined,
          title: 'Blocked devices on record',
          detail:
              '${_pluralize(overview.devices.blockedCount, 'device is', 'devices are')} blocked and should be monitored for repeat access attempts.',
          tone: _AdminAttentionTone.warning,
          actionLabel: 'Devices',
          onPressed: showDeviceAuthorizationOverview,
        ),
      );
    }

    if (overview.activity.blockedAccessCount > 0) {
      items.add(
        _AdminAttentionItem(
          icon: Icons.report_gmailerrorred_outlined,
          title: 'Blocked access attempts',
          detail:
              '${_pluralize(overview.activity.blockedAccessCount, 'blocked attempt was', 'blocked attempts were')} recorded in reader activity.',
          tone: _AdminAttentionTone.danger,
          actionLabel: 'Analytics',
          onPressed: showReaderAnalytics,
        ),
      );
    }

    if (overview.users.freeCount > 0) {
      items.add(
        _AdminAttentionItem(
          icon: Icons.workspace_premium_outlined,
          title: 'Free members to nurture',
          detail:
              '${_pluralize(overview.users.freeCount, 'reader remains', 'readers remain')} in the free access lane.',
          tone: _AdminAttentionTone.info,
          actionLabel: 'User access',
          onPressed: showUserAccessOverview,
        ),
      );
    }

    if (!overview.activity.hasActivity) {
      items.add(
        _AdminAttentionItem(
          icon: Icons.insights_outlined,
          title: 'No reader activity yet',
          detail:
              'Reader analytics will become useful after members start opening documents.',
          tone: _AdminAttentionTone.info,
          actionLabel: 'Analytics',
          onPressed: showReaderAnalytics,
        ),
      );
    }

    return items;
  }

  Widget buildAdminAttentionItem(_AdminAttentionItem item) {
    final color = adminAttentionColor(item.tone);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.detail,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          if (item.actionLabel != null && item.onPressed != null) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: item.onPressed,
              child: Text(
                item.actionLabel!,
                style: const TextStyle(color: Colors.greenAccent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildAdminAttentionPanel({
    required VaultDocumentInventorySummary inventory,
    _DashboardAdminOverview? overview,
    bool isLoading = false,
  }) {
    final items = adminAttentionItems(inventory: inventory, overview: overview);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151821),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.priority_high_outlined,
                color: Colors.orangeAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Attention needed',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isLoading)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.greenAccent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty && !isLoading)
            buildAdminAttentionItem(
              const _AdminAttentionItem(
                icon: Icons.verified_outlined,
                title: 'Everything looks steady',
                detail:
                    'No urgent vault, device, user, or reader activity issues are showing right now.',
                tone: _AdminAttentionTone.success,
              ),
            )
          else ...[
            ...items.take(5).map(buildAdminAttentionItem),
            if (items.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${items.length - 5} more item${items.length - 5 == 1 ? '' : 's'} to review in the admin tools.',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Checking member, device, and reader activity status...',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget buildAdminCommandCenter(VaultDocumentInventorySummary inventory) {
    if (!userAccess.isAdmin) return const SizedBox.shrink();

    final overviewFuture = adminOverviewFuture ??= loadDashboardAdminOverview();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin command center',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage documents, members, devices, and reader activity from one place.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh admin overview',
                onPressed: refreshDashboardAdminOverview,
                icon: const Icon(Icons.refresh, color: Colors.greenAccent),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              buildAdminMetricTile(
                icon: Icons.folder_copy_outlined,
                label: 'Vault documents',
                value: inventory.totalCount.toString(),
                detail:
                    '${inventory.freeCount} free | ${inventory.premiumCount} protected',
                color: Colors.greenAccent,
              ),
              buildAdminMetricTile(
                icon: Icons.category_outlined,
                label: 'Categories',
                value: inventory.categoryCounts.length.toString(),
                detail: inventory.latestDocument == null
                    ? 'No recent document yet'
                    : 'Latest: ${inventory.latestDocument!.name}',
                color: Colors.orangeAccent,
              ),
              FutureBuilder<_DashboardAdminOverview>(
                future: overviewFuture,
                builder: (context, snapshot) {
                  final overview = snapshot.data;
                  return buildAdminMetricTile(
                    icon: Icons.people_alt_outlined,
                    label: 'Members',
                    value: overview?.users.totalCount.toString() ?? '...',
                    detail: overview == null
                        ? 'Loading access summary'
                        : '${overview.users.adminCount} admins | ${overview.users.premiumCount} premium | ${overview.users.freeCount} free',
                    color: Colors.lightBlueAccent,
                  );
                },
              ),
              FutureBuilder<_DashboardAdminOverview>(
                future: overviewFuture,
                builder: (context, snapshot) {
                  final overview = snapshot.data;
                  return buildAdminMetricTile(
                    icon: Icons.devices_other_outlined,
                    label: 'Devices',
                    value: overview?.devices.totalCount.toString() ?? '...',
                    detail: overview == null
                        ? 'Loading device summary'
                        : '${overview.devices.pendingCount} pending | ${overview.devices.trustedCount} trusted | ${overview.devices.blockedCount} blocked',
                    color: Colors.pinkAccent,
                  );
                },
              ),
              FutureBuilder<_DashboardAdminOverview>(
                future: overviewFuture,
                builder: (context, snapshot) {
                  final overview = snapshot.data;
                  return buildAdminMetricTile(
                    icon: Icons.insights_outlined,
                    label: 'Reader events',
                    value:
                        overview?.activity.totalEventCount.toString() ?? '...',
                    detail: overview == null
                        ? 'Loading reader activity'
                        : '${overview.activity.uniqueReaderCount} readers | ${overview.activity.blockedAccessCount} blocked',
                    color: Colors.cyanAccent,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          buildAdminVaultHealth(inventory),
          const SizedBox(height: 18),
          FutureBuilder<_DashboardAdminOverview>(
            future: overviewFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildAdminAttentionPanel(inventory: inventory),
                    const SizedBox(height: 8),
                    const Text(
                      'Member, device, and reader activity checks could not load right now.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
                );
              }

              return buildAdminAttentionPanel(
                inventory: inventory,
                overview: snapshot.data,
                isLoading: !snapshot.hasData,
              );
            },
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              buildAdminActionButton(
                icon: Icons.upload_file,
                label: 'Upload PDF',
                detail: 'Add a profiled document',
                onPressed: uploadPDF,
              ),
              buildAdminActionButton(
                icon: Icons.manage_search,
                label: 'Refresh index',
                detail: 'Rebuild searchable text',
                onPressed: indexVaultPdfsFromAdminPanel,
              ),
              buildAdminActionButton(
                icon: Icons.inventory_2_outlined,
                label: 'Inventory',
                detail: 'Open vault breakdown',
                onPressed: showVaultInventory,
              ),
              buildAdminActionButton(
                icon: Icons.manage_accounts_outlined,
                label: 'User access',
                detail: 'Review plans and roles',
                onPressed: showUserAccessOverview,
              ),
              buildAdminActionButton(
                icon: Icons.important_devices_outlined,
                label: 'Devices',
                detail: 'Trust or block devices',
                onPressed: showDeviceAuthorizationOverview,
              ),
              buildAdminActionButton(
                icon: Icons.insights_outlined,
                label: 'Analytics',
                detail: 'Reader activity report',
                onPressed: showReaderAnalytics,
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final panelWidth = constraints.maxWidth > 1060
                  ? (constraints.maxWidth - 28) / 3
                  : constraints.maxWidth > 760
                  ? (constraints.maxWidth - 14) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: panelWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Documents by category',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        buildAdminCategoryBars(inventory),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: panelWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent document updates',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        buildAdminRecentDocuments(inventory),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: panelWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent reader activity',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FutureBuilder<_DashboardAdminOverview>(
                          future: overviewFuture,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const Text(
                                'Admin activity could not load right now.',
                                style: TextStyle(color: Colors.redAccent),
                              );
                            }

                            if (!snapshot.hasData) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: LinearProgressIndicator(
                                  color: Colors.greenAccent,
                                  backgroundColor: Colors.white10,
                                ),
                              );
                            }

                            return buildAdminActivityList(
                              snapshot.data!.activity,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canAccessMainVault = userAccess.canAccessMainVault;
    final filteredFreePdfFiles = filterVaultDocumentsForDashboard(
      freePdfFiles,
      category: freeDocumentCategoryFilter,
      query: dashboardDocumentSearchQuery,
    );
    final filteredPremiumPdfFiles = filterVaultDocumentsForDashboard(
      premiumPdfFiles,
      category: premiumDocumentCategoryFilter,
      query: dashboardDocumentSearchQuery,
    );
    final hasDashboardDocumentSearch = dashboardDocumentSearchQuery
        .trim()
        .isNotEmpty;
    final hasFreeDocumentFilter =
        hasDashboardDocumentSearch ||
        freeDocumentCategoryFilter.trim().isNotEmpty;
    final hasPremiumDocumentFilter =
        hasDashboardDocumentSearch ||
        premiumDocumentCategoryFilter.trim().isNotEmpty;
    final dashboardFilterLabels = vaultDocumentActiveFilterLabels(
      query: dashboardDocumentSearchQuery,
      freeCategory: freeDocumentCategoryFilter,
      premiumCategory: premiumDocumentCategoryFilter,
    );
    final vaultInventory = VaultDocumentInventorySummary.fromDocuments(
      freeDocuments: freePdfFiles,
      premiumDocuments: premiumPdfFiles,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Ancient Secure Vault',
          style: TextStyle(color: Colors.greenAccent),
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.greenAccent),

            onPressed: globalSearch,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.greenAccent),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          canAccessMainVault
                              ? 'Main Vault Access: Active'
                              : 'Free Zone Only - Subscribe to unlock the Main Vault',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 30),

                        if (pdfLoadError != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.redAccent),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.redAccent,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    pdfLoadError!,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                TextButton(
                                  onPressed: loadPDFs,
                                  child: const Text(
                                    'Retry',
                                    style: TextStyle(color: Colors.greenAccent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        if (userAccess.isAdmin) ...[
                          buildAdminCommandCenter(vaultInventory),
                          const SizedBox(height: 24),
                        ],

                        buildDashboardDocumentSearch(),
                        buildDashboardActiveFilterBar(dashboardFilterLabels),

                        const SizedBox(height: 20),

                        Text(
                          vaultDocumentSectionTitle(
                            title: 'FREE ACCESS ZONE',
                            visibleCount: filteredFreePdfFiles.length,
                            totalCount: freePdfFiles.length,
                            hasActiveFilter: hasFreeDocumentFilter,
                          ),
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 15),

                        buildDocumentCategoryFilter(
                          filterId: 'free',
                          documents: freePdfFiles,
                          selectedCategory: freeDocumentCategoryFilter,
                          onChanged: (category) {
                            setState(() {
                              freeDocumentCategoryFilter = category;
                            });
                          },
                        ),

                        if (freePdfFiles.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No free PDFs available yet.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        else if (filteredFreePdfFiles.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              hasDashboardDocumentSearch
                                  ? 'No free PDFs match these filters.'
                                  : 'No free PDFs match this category.',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredFreePdfFiles.length,
                            itemBuilder: (context, index) {
                              final pdfFile = filteredFreePdfFiles[index];

                              return Card(
                                color: Colors.orange.withValues(alpha: 0.12),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.orangeAccent,
                                  ),
                                  title: Text(
                                    pdfFile['name'],
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    vaultDocumentListSubtitle(
                                      pdfFile,
                                      accessLabel: 'Free Access PDF',
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  trailing: userAccess.canManageVault
                                      ? IconButton(
                                          tooltip: 'Manage document',
                                          icon: const Icon(
                                            Icons.admin_panel_settings,
                                          ),
                                          color: Colors.orangeAccent,
                                          onPressed: () {
                                            showVaultDocumentAdminDialog(
                                              pdfFile,
                                              accessLabel: 'Free Access PDF',
                                            );
                                          },
                                        )
                                      : null,
                                  onTap: () async {
                                    final pdfUrl =
                                        await resolveSearchResultPdfUrl(
                                          pdfFile,
                                        );

                                    if (pdfUrl == null) return;

                                    if (!context.mounted) return;

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PDFViewerScreen(
                                          pdfUrl: pdfUrl,
                                          title: pdfFile['name'],
                                          accessLevel:
                                              pdfFile['accessLevel']
                                                  ?.toString() ??
                                              'free',
                                          readerMode:
                                              pdfFile['readerMode']
                                                  ?.toString() ??
                                              '',
                                          protectionMode:
                                              pdfFile['protectionMode']
                                                  ?.toString() ??
                                              '',
                                          openSource: 'free_dashboard',
                                          storagePath:
                                              pdfFile['storagePath']
                                                  ?.toString() ??
                                              '',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 30),
                        if (canAccessMainVault) ...[
                          Text(
                            vaultDocumentSectionTitle(
                              title: 'MAIN VAULT PDFs',
                              visibleCount: filteredPremiumPdfFiles.length,
                              totalCount: premiumPdfFiles.length,
                              hasActiveFilter: hasPremiumDocumentFilter,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 15),

                          buildDocumentCategoryFilter(
                            filterId: 'premium',
                            documents: premiumPdfFiles,
                            selectedCategory: premiumDocumentCategoryFilter,
                            onChanged: (category) {
                              setState(() {
                                premiumDocumentCategoryFilter = category;
                              });
                            },
                          ),

                          if (premiumPdfFiles.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'No protected PDFs available yet.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          else if (filteredPremiumPdfFiles.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                hasDashboardDocumentSearch
                                    ? 'No protected PDFs match these filters.'
                                    : 'No protected PDFs match this category.',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredPremiumPdfFiles.length,
                              itemBuilder: (context, index) {
                                final pdfFile = filteredPremiumPdfFiles[index];

                                return Card(
                                  color: Colors.green.withValues(alpha: 0.12),

                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.picture_as_pdf,
                                      color: Colors.greenAccent,
                                    ),

                                    title: Text(
                                      pdfFile['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),

                                    subtitle: Text(
                                      vaultDocumentListSubtitle(
                                        pdfFile,
                                        accessLabel: 'Protected PDF',
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),

                                    trailing: userAccess.canManageVault
                                        ? IconButton(
                                            tooltip: 'Manage document',
                                            icon: const Icon(
                                              Icons.admin_panel_settings,
                                            ),
                                            color: Colors.greenAccent,
                                            onPressed: () {
                                              showVaultDocumentAdminDialog(
                                                pdfFile,
                                                accessLabel: 'Protected PDF',
                                              );
                                            },
                                          )
                                        : null,

                                    onTap: () async {
                                      final pdfUrl =
                                          await resolveSearchResultPdfUrl(
                                            pdfFile,
                                          );

                                      if (pdfUrl == null) return;

                                      if (!context.mounted) return;

                                      Navigator.push(
                                        context,

                                        MaterialPageRoute(
                                          builder: (context) => PDFViewerScreen(
                                            pdfUrl: pdfUrl,
                                            title: pdfFile['name'],
                                            accessLevel:
                                                pdfFile['accessLevel']
                                                    ?.toString() ??
                                                'premium',
                                            readerMode:
                                                pdfFile['readerMode']
                                                    ?.toString() ??
                                                '',
                                            protectionMode:
                                                pdfFile['protectionMode']
                                                    ?.toString() ??
                                                '',
                                            openSource: 'premium_dashboard',
                                            storagePath:
                                                pdfFile['storagePath']
                                                    ?.toString() ??
                                                '',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ReaderAnalyticsMetric extends StatelessWidget {
  const _ReaderAnalyticsMetric({
    required this.label,
    required this.value,
    this.color = Colors.greenAccent,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class PDFViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;
  final int initialPage;
  final String initialSearchQuery;
  final String accessLevel;
  final String readerMode;
  final String protectionMode;
  final String openSource;
  final String storagePath;

  const PDFViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
    this.initialPage = 0,
    this.initialSearchQuery = '',
    this.accessLevel = 'free',
    this.readerMode = '',
    this.protectionMode = '',
    this.openSource = 'direct_open',
    this.storagePath = '',
  });

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _ProtectedPdfPageRenderJob {
  const _ProtectedPdfPageRenderJob({
    required this.page,
    required this.canvas,
    required this.renderViewport,
    required this.placeholder,
  });

  final Object page;
  final html.CanvasElement canvas;
  final Object renderViewport;
  final html.HtmlElement placeholder;
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  static Future<void>? _pdfJsReady;

  final TextEditingController searchController = TextEditingController();

  String accessFilter = 'all';

  String searchQuery = '';
  ReaderSavedPosition? latestReadingPosition;
  late final String viewId;
  html.IFrameElement? pdfIframe;
  html.DivElement? protectedPdfImageContainer;
  int currentPdfPage = 1;
  int? pdfPageCount;
  String currentSearchQuery = '';
  bool isCheckingViewerAccess = true;
  bool canViewDocument = false;
  UserAccessState readerUserAccess = const UserAccessState();
  bool readerSessionStarted = false;
  bool showReaderStatusOverlay = true;
  bool readerWindowIsActive = true;
  DateTime? readerSessionStartedAt;
  StreamSubscription<html.Event>? readerVisibilitySubscription;
  StreamSubscription<html.Event>? readerWindowBlurSubscription;
  StreamSubscription<html.Event>? readerWindowFocusSubscription;
  StreamSubscription<html.MouseEvent>? readerContextMenuSubscription;
  StreamSubscription<html.MouseEvent>? readerPdfContextMenuSubscription;
  StreamSubscription<html.MouseEvent>? readerPdfMouseDownSubscription;
  StreamSubscription<html.Event>? protectedPdfScrollSubscription;
  StreamSubscription<html.MouseEvent>? protectedPdfContextMenuSubscription;
  StreamSubscription<html.MouseEvent>? protectedPdfMouseDownSubscription;
  StreamSubscription<html.KeyboardEvent>? readerKeyDownSubscription;
  int protectedPdfRenderGeneration = 0;
  bool protectedPdfRenderStarted = false;
  late final String readerSessionId;
  late final ReaderTtsService readerTtsService;
  late final ReaderNarrationProgressRepository narrationProgressRepository;
  late final ReaderNarrationProgressController narrationProgressController;
  late final ReaderNarrationPreferencesRepository
  narrationPreferencesRepository;
  late final ReaderNarrationPreferencesController
  narrationPreferencesController;
  late final ReaderNarrationSessionRepository narrationSessionRepository;
  late final ReaderNarrationSessionTracker narrationSessionTracker;
  late final ReaderBookmarkRepository readerBookmarkRepository;
  late final ReaderHighlightRepository readerHighlightRepository;
  late final ReaderNoteRepository readerNoteRepository;
  late final ReaderSavedPositionRepository savedPositionRepository;
  late final ReaderActivityRepository readerActivityRepository;
  late final ReaderDeviceIdentity readerDeviceIdentity;
  late final UserDeviceAuthorizationRepository
  readerDeviceAuthorizationRepository;
  late final UserAccessRepository userAccessRepository;
  late final ReaderCloudNarrationSessionCoordinator narrationCloudSession;
  late final ReaderNarrationPlaybackCoordinator narrationPlaybackCoordinator;
  late final ReaderNarrationVoiceCatalogPresenter narrationVoicePresenter;
  late final ReaderNarrationNavigator narrationNavigator;
  late final Future<void> narrationPreferencesReady;
  final Map<int, String> narrationPageTextCache = {};
  Future<List<int>>? narrationPdfBytesFuture;

  String get shortReaderSessionId {
    if (readerSessionId.length <= 8) {
      return readerSessionId;
    }

    return readerSessionId.substring(readerSessionId.length - 8);
  }

  String get normalizedReaderStoragePath => widget.storagePath.trim();

  String get readerDocumentKey {
    final storagePath = normalizedReaderStoragePath;
    return storagePath.isNotEmpty ? storagePath : widget.title;
  }

  ReaderNarrationProgressContext get narrationProgressContext =>
      ReaderNarrationProgressContext(
        userEmail: FirebaseAuth.instance.currentUser?.email,
        documentKey: readerDocumentKey,
        pdfTitle: widget.title,
        storagePath: normalizedReaderStoragePath,
      );

  ReaderNarrationPreferencesContext get narrationPreferencesContext =>
      ReaderNarrationPreferencesContext(
        userEmail: FirebaseAuth.instance.currentUser?.email,
      );

  ReaderProtectionPolicy get readerProtectionPolicy => ReaderProtectionPolicy(
    documentAccessLevel: widget.accessLevel,
    readerMode: widget.readerMode,
    protectionMode: widget.protectionMode,
    hasActiveSubscription: readerUserAccess.hasActiveSubscription,
    isAdmin: readerUserAccess.isAdmin,
  );

  bool get shouldShowReaderPrivacyShield {
    return canViewDocument &&
        readerProtectionPolicy.shouldBlurWhenInactive &&
        !readerWindowIsActive;
  }

  ReaderActivityLogContext get readerActivityLogContext =>
      ReaderActivityLogContext(
        userEmail: FirebaseAuth.instance.currentUser?.email,
        pdfTitle: widget.title,
        readerSessionId: readerSessionId,
        documentAccessLevel: widget.accessLevel,
        openSource: widget.openSource,
        documentKey: readerDocumentKey,
        storagePath: normalizedReaderStoragePath,
        deviceId: readerDeviceIdentity.id,
        deviceLabel: readerDeviceIdentity.label,
        devicePlatform: readerDeviceIdentity.platform,
      );

  String get readerSourceLabel => widget.openSource.replaceAll('_', ' ');

  String get readerAccessLabel => widget.accessLevel.trim().toUpperCase();

  ReaderNarrationAccessPolicy get narrationAccessPolicy {
    return ReaderNarrationAccessPolicy.fromUserAccess(
      isAdmin: readerUserAccess.isAdmin,
      hasActiveSubscription: readerUserAccess.hasActiveSubscription,
    );
  }

  ReaderNarrationVoiceCatalogViewModel narrationVoiceCatalogView() {
    final snapshot = narrationPlaybackCoordinator.snapshot();
    return narrationVoicePresenter.present(
      catalog: snapshot.catalog,
      activeVoice: readerTtsService.activeVoice,
      activeLocale: readerTtsService.activeLocale,
    );
  }

  String twoDigits(int value) => value.toString().padLeft(2, '0');

  String formatReaderTimestamp(DateTime? value) {
    if (value == null) return 'pending';

    return '${value.year}-'
        '${twoDigits(value.month)}-'
        '${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:'
        '${twoDigits(value.minute)}';
  }

  String formatSavedPositionTime(dynamic value) {
    if (value is Timestamp) {
      return formatReaderTimestamp(value.toDate());
    }

    return 'saving...';
  }

  int readStoredPageNumber(dynamic value) {
    final page = int.tryParse(value.toString()) ?? 1;

    return page < 1 ? 1 : page;
  }

  static const List<String> readerNoteCategories = [
    'General',
    'Research',
    'Action',
    'Question',
    'Important',
  ];

  static const Map<String, Color> readerHighlightColors = {
    'yellow': Color(0xFFFFD54F),
    'green': Color(0xFF69F0AE),
    'blue': Color(0xFF64B5F6),
    'pink': Color(0xFFF48FB1),
    'red': Color(0xFFFF8A80),
  };

  String normalizeReaderHighlightColor(String value) {
    final color = value.trim().toLowerCase();
    return readerHighlightColors.containsKey(color) ? color : 'yellow';
  }

  Color readerHighlightColor(String value) {
    return readerHighlightColors[normalizeReaderHighlightColor(value)] ??
        readerHighlightColors['yellow']!;
  }

  String readerHighlightColorLabel(String value) {
    final color = normalizeReaderHighlightColor(value);
    return color[0].toUpperCase() + color.substring(1);
  }

  String normalizeReaderNoteCategory(String value) {
    final category = value.trim();
    if (category.isEmpty) return readerNoteCategories.first;

    return readerNoteCategories.contains(category)
        ? category
        : readerNoteCategories.first;
  }

  String formatReaderNoteTime(ReaderNote note) {
    final updatedAt = note.updatedAt;

    if (updatedAt is Timestamp) {
      return 'Updated: ${formatReaderTimestamp(updatedAt.toDate())}';
    }

    return 'Saved: ${formatSavedPositionTime(note.createdAt)}';
  }

  String formatReaderHighlightTime(ReaderHighlight highlight) {
    return 'Saved: ${formatSavedPositionTime(highlight.createdAt)}';
  }

  String formatReaderBookmarkTime(ReaderBookmark bookmark) {
    final updatedAt = bookmark.updatedAt;

    if (updatedAt is Timestamp) {
      return 'Updated: ${formatReaderTimestamp(updatedAt.toDate())}';
    }

    return 'Saved: ${formatSavedPositionTime(bookmark.createdAt)}';
  }

  String formatSearchResultSummary(List<Map<String, dynamic>> results) {
    final matchedPages = results
        .map((result) => readStoredPageNumber(result['pageNumber']))
        .toSet()
        .length;
    final matchLabel = results.length == 1 ? 'match' : 'matches';
    final pageLabel = matchedPages == 1 ? 'page' : 'pages';

    return '${results.length} $matchLabel across $matchedPages $pageLabel';
  }

  String get readerStatusText {
    final searchText = currentSearchQuery.trim();
    final searchStatus = searchText.isEmpty
        ? 'No active search'
        : 'Search: $searchText';
    final pageStatus = pdfPageCount == null
        ? 'Page $currentPdfPage'
        : 'Page $currentPdfPage of $pdfPageCount';

    return '$pageStatus | $readerAccessLabel | $searchStatus';
  }

  String get readerWatermarkText {
    return 'Protected by Ancient Secure Docs\n'
        '${FirebaseAuth.instance.currentUser?.email ?? ''}\n'
        'Session: $shortReaderSessionId\n'
        'Access: $readerAccessLabel | Source: $readerSourceLabel\n'
        'Opened: ${formatReaderTimestamp(readerSessionStartedAt)}';
  }

  Widget buildPdfDocumentSurface() {
    return IgnorePointer(
      ignoring: shouldShowReaderPrivacyShield,
      child: HtmlElementView(viewType: viewId),
    );
  }

  Widget buildProtectedPdfLoadingSurface() {
    return Container(
      color: const Color(0xFF111217),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.greenAccent),
          SizedBox(height: 16),
          Text(
            'Preparing protected page images...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Future<UserAccessState> loadCurrentUserAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    return userAccessRepository.loadForEmail(user?.email);
  }

  Future<void> checkViewerAccess() async {
    final access = await loadCurrentUserAccess();
    final deviceStatus = await recordReaderDeviceSeen();
    final accessDecision = ReaderAccessDecision.evaluate(
      userAccess: access,
      documentAccessLevel: widget.accessLevel,
      deviceStatus: deviceStatus,
      enforceDeviceAuthorization: userDeviceAuthorizationIsEnforced(
        readerDeviceAuthorizationMode,
      ),
    );

    if (!mounted) return;

    await logReaderAccessAttempt(decision: accessDecision, userAccess: access);

    if (!mounted) return;

    setState(() {
      readerUserAccess = access;
      canViewDocument = accessDecision.allowed;
      isCheckingViewerAccess = false;
    });

    if (!accessDecision.allowed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(accessDecision.blockedMessage)));
      return;
    }

    registerPdfViewer();
    readerSessionStarted = true;
    readerSessionStartedAt = DateTime.now();
    await logReaderSessionLifecycle(
      'started',
      details: {
        'initialPage': widget.initialPage,
        'currentPdfPage': currentPdfPage,
        'hasInitialSearchQuery': widget.initialSearchQuery.trim().isNotEmpty,
      },
    );
    loadLatestReadingPosition();
  }

  Future<void> logReaderAccessAttempt({
    required ReaderAccessDecision decision,
    required UserAccessState userAccess,
  }) async {
    try {
      await readerActivityRepository.logAccessAttempt(
        ReaderAccessLogDraft(
          context: readerActivityLogContext,
          userAccessLevel: userAccess.accessLevel,
          initialPage: widget.initialPage,
          hasInitialSearchQuery: widget.initialSearchQuery.trim().isNotEmpty,
          isAdmin: userAccess.isAdmin,
          hasActiveSubscription: userAccess.hasActiveSubscription,
          allowed: decision.allowed,
          accessDecisionReason: decision.reasonKey,
          deviceAuthorizationStatus: decision.deviceStatusKey,
          deviceAuthorizationMode: userDeviceAuthorizationModeKey(
            readerDeviceAuthorizationMode,
          ),
          deviceAuthorizationEnforced: decision.deviceAuthorizationEnforced,
        ),
      );
    } catch (_) {
      // Logging should not block the reader if Firestore rules are not ready yet.
    }
  }

  Future<UserDeviceStatus?> recordReaderDeviceSeen() async {
    try {
      return readerDeviceAuthorizationRepository.recordSeenDevice(
        UserDeviceSeenDraft(
          deviceId: readerDeviceIdentity.id,
          email: FirebaseAuth.instance.currentUser?.email,
          deviceLabel: readerDeviceIdentity.label,
          platform: readerDeviceIdentity.platform,
          lastDocumentTitle: widget.title,
          lastOpenSource: widget.openSource,
        ),
      );
    } catch (_) {
      // Device monitoring must not block the reader while rules are being prepared.
      return null;
    }
  }

  Future<void> logReaderAction({
    required String action,
    Map<String, dynamic> details = const {},
  }) async {
    try {
      await readerActivityRepository.logAction(
        ReaderActionLogDraft(
          context: readerActivityLogContext,
          action: action,
          details: details,
        ),
      );
    } catch (_) {
      // Activity logging should not interrupt the reader experience.
    }
  }

  Future<void> logReaderSessionLifecycle(
    String event, {
    Map<String, dynamic> details = const {},
  }) async {
    try {
      await readerActivityRepository.logSessionLifecycle(
        ReaderSessionLogDraft(
          context: readerActivityLogContext,
          event: event,
          details: details,
        ),
      );
    } catch (_) {
      // Session logging should not interrupt the reader experience.
    }
  }

  bool canUseViewerTools(String attemptedAction) {
    if (canViewDocument) return true;

    logReaderAction(
      action: 'blocked_reader_tool_attempt',
      details: {'attemptedAction': attemptedAction},
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Subscription required to use this PDF.')),
    );

    return false;
  }

  List<QueryDocumentSnapshot> sortReadingPositionsByNewest(
    List<QueryDocumentSnapshot> positions,
  ) {
    final sortedPositions = List<QueryDocumentSnapshot>.from(positions);

    sortedPositions.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aCreatedAt = aData['createdAt'];
      final bCreatedAt = bData['createdAt'];

      if (aCreatedAt is Timestamp && bCreatedAt is Timestamp) {
        return bCreatedAt.compareTo(aCreatedAt);
      }

      return 0;
    });

    return sortedPositions;
  }

  Future<void> loadLatestReadingPosition() async {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email;
    if (userEmail == null || userEmail.isEmpty) return;

    final position = await savedPositionRepository.loadLatest(
      userEmail: userEmail,
      pdfTitle: widget.title,
    );

    if (position != null) {
      latestReadingPosition = position;

      if (widget.initialPage == 0) {
        openPdfPage(position.pageNumber, source: 'latest_saved_position');
      }
    }
  }

  String buildPdfViewerUrl({required int pageNumber, String searchQuery = ''}) {
    final safePageNumber = pageNumber < 1 ? 1 : pageNumber;
    final safeSearchQuery = searchQuery.trim();
    final searchFragment = safeSearchQuery.isEmpty
        ? ''
        : '&search=${Uri.encodeComponent(safeSearchQuery)}';

    return '${widget.pdfUrl}#toolbar=0&navpanes=0&scrollbar=1&page=$safePageNumber$searchFragment';
  }

  void registerPdfViewer() {
    ui.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
      if (readerProtectionPolicy.usesProtectedImageReader) {
        final container = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.overflowY = 'auto'
          ..style.overflowX = 'hidden'
          ..style.background = '#202124'
          ..style.padding = '18px 0 96px'
          ..style.boxSizing = 'border-box'
          ..style.userSelect = 'none';

        container.children.add(
          html.DivElement()
            ..text = 'Preparing protected page images...'
            ..style.color = '#C8C8C8'
            ..style.fontFamily = 'Arial, sans-serif'
            ..style.fontSize = '15px'
            ..style.padding = '32px'
            ..style.textAlign = 'center',
        );

        protectedPdfContextMenuSubscription = container.onContextMenu.listen((
          event,
        ) {
          handleProtectedReaderAction(
            source: 'protected_image_context_menu',
            event: event,
          );
        });
        protectedPdfMouseDownSubscription = container.onMouseDown.listen((
          event,
        ) {
          if (event.button != 2) return;

          handleProtectedReaderAction(
            source: 'protected_image_right_click',
            event: event,
          );
        });
        protectedPdfScrollSubscription = container.onScroll.listen(
          handleProtectedPdfImageScroll,
        );

        pdfIframe = null;
        protectedPdfImageContainer = container;
        scheduleMicrotask(renderProtectedPdfImages);
        return container;
      }

      final iframe = html.IFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.userSelect = 'none'
        ..style.pointerEvents = 'auto';

      readerPdfContextMenuSubscription?.cancel();
      readerPdfMouseDownSubscription?.cancel();
      readerPdfContextMenuSubscription = iframe.onContextMenu.listen((event) {
        handleProtectedReaderAction(source: 'pdf_context_menu', event: event);
      });
      readerPdfMouseDownSubscription = iframe.onMouseDown.listen((event) {
        if (event.button != 2) return;

        handleProtectedReaderAction(source: 'pdf_right_click', event: event);
      });

      pdfIframe = iframe;
      protectedPdfImageContainer = null;
      updatePdfIframeSource(
        pageNumber: currentPdfPage,
        searchQuery: currentSearchQuery,
      );
      return iframe;
    });
  }

  void updatePdfIframeSource({
    required int pageNumber,
    required String searchQuery,
  }) {
    final iframe = pdfIframe;
    if (iframe == null) return;

    final url = buildPdfViewerUrl(
      pageNumber: pageNumber,
      searchQuery: searchQuery,
    );
    iframe.src = url;
  }

  Future<void> ensurePdfJsReady() {
    final existing = _pdfJsReady;
    if (existing != null) return existing;

    final completer = Completer<void>();
    _pdfJsReady = completer.future;

    if (js_util.getProperty<Object?>(html.window, 'pdfjsLib') != null) {
      configurePdfJsWorker();
      completer.complete();
      return completer.future;
    }

    final script = html.ScriptElement()
      ..src =
          'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/2.16.105/pdf.min.js'
      ..async = true;

    script.onLoad.first.then((_) {
      configurePdfJsWorker();
      completer.complete();
    });
    script.onError.first.then((_) {
      _pdfJsReady = null;
      completer.completeError(
        StateError('Protected PDF image renderer could not load.'),
      );
    });

    html.document.head?.append(script);
    return completer.future;
  }

  void configurePdfJsWorker() {
    final pdfJs = js_util.getProperty<Object?>(html.window, 'pdfjsLib');
    if (pdfJs == null) return;

    final workerOptions = js_util.getProperty<Object>(
      pdfJs,
      'GlobalWorkerOptions',
    );
    js_util.setProperty(
      workerOptions,
      'workerSrc',
      'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/2.16.105/pdf.worker.min.js',
    );
  }

  Future<void> renderProtectedPdfImages() async {
    final container = protectedPdfImageContainer;
    if (container == null || protectedPdfRenderStarted) return;

    protectedPdfRenderStarted = true;
    final renderGeneration = ++protectedPdfRenderGeneration;

    try {
      await ensurePdfJsReady();
      if (renderGeneration != protectedPdfRenderGeneration) return;

      final pdfJs = js_util.getProperty<Object>(html.window, 'pdfjsLib');
      final loadingTask = js_util.callMethod<Object>(pdfJs, 'getDocument', [
        js_util.jsify({
          'url': widget.pdfUrl,
          'disableAutoFetch': false,
          'disableStream': false,
        }),
      ]);
      final document = await js_util.promiseToFuture<Object>(
        js_util.getProperty<Object>(loadingTask, 'promise'),
      );
      if (renderGeneration != protectedPdfRenderGeneration) return;

      final pageCount = (js_util.getProperty<num>(
        document,
        'numPages',
      )).toInt();
      pdfPageCount = pageCount;
      if (mounted) setState(() {});

      container.children.clear();
      container.style.background = '#2A2A2A';
      final renderJobs = <_ProtectedPdfPageRenderJob>[];

      for (var pageNumber = 1; pageNumber <= pageCount; pageNumber++) {
        if (renderGeneration != protectedPdfRenderGeneration) return;

        final page = await js_util.promiseToFuture<Object>(
          js_util.callMethod<Object>(document, 'getPage', [pageNumber]),
        );
        final baseViewport = js_util.callMethod<Object>(page, 'getViewport', [
          js_util.jsify({'scale': 1}),
        ]);
        final baseWidth = js_util.getProperty<num>(baseViewport, 'width');
        final containerWidth = container.clientWidth == 0
            ? 900
            : container.clientWidth;
        final availableWidth = math.max(320, containerWidth - 48);
        final displayScale = (availableWidth / baseWidth).clamp(0.6, 1.8);
        final targetPixelRatio = pageCount <= 12
            ? 2.35
            : pageCount <= 60
            ? 1.65
            : 1.25;
        final pixelRatio = math.min(
          math.max(html.window.devicePixelRatio, targetPixelRatio),
          2.6,
        );
        final renderScale = displayScale * pixelRatio;
        final displayViewport = js_util.callMethod<Object>(
          page,
          'getViewport',
          [
            js_util.jsify({'scale': displayScale}),
          ],
        );
        final renderViewport = js_util.callMethod<Object>(page, 'getViewport', [
          js_util.jsify({'scale': renderScale}),
        ]);

        final displayWidth = js_util.getProperty<num>(displayViewport, 'width');
        final displayHeight = js_util.getProperty<num>(
          displayViewport,
          'height',
        );
        final renderWidth = js_util.getProperty<num>(renderViewport, 'width');
        final renderHeight = js_util.getProperty<num>(renderViewport, 'height');

        final wrapper = html.DivElement()
          ..dataset['readerPageNumber'] = pageNumber.toString()
          ..style.width = '${displayWidth}px'
          ..style.margin = '0 auto 18px'
          ..style.background = '#FFFFFF'
          ..style.boxShadow = '0 2px 14px rgba(0,0,0,0.35)'
          ..style.position = 'relative'
          ..style.userSelect = 'none';
        final placeholder = html.DivElement()
          ..text = 'Preparing protected page $pageNumber...'
          ..style.width = '${displayWidth}px'
          ..style.height = '${displayHeight}px'
          ..style.display = 'flex'
          ..style.alignItems = 'center'
          ..style.justifyContent = 'center'
          ..style.color = '#8B8F99'
          ..style.fontFamily = 'Arial, sans-serif'
          ..style.fontSize = '14px'
          ..style.position = 'absolute'
          ..style.left = '0'
          ..style.top = '0'
          ..style.zIndex = '1'
          ..style.pointerEvents = 'none'
          ..style.userSelect = 'none';
        final canvas =
            html.CanvasElement(
                width: renderWidth.ceil(),
                height: renderHeight.ceil(),
              )
              ..style.width = '${displayWidth}px'
              ..style.height = '${displayHeight}px'
              ..style.display = 'block'
              ..style.filter = 'contrast(1.12) brightness(0.98)'
              ..style.imageRendering = 'auto'
              ..style.userSelect = 'none';

        wrapper.children.add(placeholder);
        wrapper.children.add(canvas);
        container.children.add(wrapper);
        renderJobs.add(
          _ProtectedPdfPageRenderJob(
            page: page,
            canvas: canvas,
            renderViewport: renderViewport,
            placeholder: placeholder,
          ),
        );
      }

      scrollProtectedPdfImageReaderToPage(currentPdfPage);

      for (final job in renderJobs) {
        if (renderGeneration != protectedPdfRenderGeneration) return;

        final context = job.canvas.context2D;
        js_util.setProperty(context, 'imageSmoothingEnabled', true);
        js_util.setProperty(context, 'imageSmoothingQuality', 'high');
        final renderTask = js_util.callMethod<Object>(job.page, 'render', [
          js_util.jsify({
            'canvasContext': context,
            'viewport': job.renderViewport,
          }),
        ]);
        await js_util.promiseToFuture<Object>(
          js_util.getProperty<Object>(renderTask, 'promise'),
        );

        if (renderGeneration != protectedPdfRenderGeneration) return;

        job.placeholder.remove();
      }
    } catch (error) {
      if (renderGeneration != protectedPdfRenderGeneration) return;

      container.children.clear();
      container.children.add(
        html.DivElement()
          ..text =
              'Protected PDF image reader could not prepare this document. '
              'Please try again.'
          ..style.color = '#FF8A80'
          ..style.fontFamily = 'Arial, sans-serif'
          ..style.fontSize = '15px'
          ..style.padding = '32px'
          ..style.textAlign = 'center',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Protected PDF image reader could not load.'),
          ),
        );
      }
    }
  }

  void handleProtectedPdfImageScroll(html.Event event) {
    final container = protectedPdfImageContainer;
    if (container == null || pdfPageCount == null) return;

    final viewportAnchor =
        container.scrollTop + (container.clientHeight * 0.35);
    var visiblePage = currentPdfPage;

    for (final child in container.children) {
      final pageElement = child as html.HtmlElement;
      final pageNumber = int.tryParse(
        pageElement.dataset['readerPageNumber'] ?? '',
      );
      if (pageNumber == null) continue;

      if (pageElement.offsetTop <= viewportAnchor) {
        visiblePage = pageNumber;
      } else {
        break;
      }
    }

    if (visiblePage == currentPdfPage) return;

    if (mounted) {
      setState(() {
        currentPdfPage = visiblePage;
      });
    } else {
      currentPdfPage = visiblePage;
    }
    preloadNarrationTextForPage(visiblePage);
  }

  void scrollProtectedPdfImageReaderToPage(int pageNumber) {
    final container = protectedPdfImageContainer;
    if (container == null) return;

    final pageElement = container.querySelector(
      '[data-reader-page-number="$pageNumber"]',
    );
    if (pageElement is! html.HtmlElement) return;

    container.scrollTop = math.max(0, pageElement.offsetTop - 12);
  }

  void startReaderProtectionObservers() {
    readerVisibilitySubscription = html.document.onVisibilityChange.listen((_) {
      updateReaderWindowActivity(
        isActive: !html.document.hidden!,
        source: 'visibility_change',
      );
    });
    readerWindowBlurSubscription = html.window.onBlur.listen((_) {
      updateReaderWindowActivity(isActive: false, source: 'window_blur');
    });
    readerWindowFocusSubscription = html.window.onFocus.listen((_) {
      updateReaderWindowActivity(isActive: true, source: 'window_focus');
    });
    readerContextMenuSubscription = html.document.onContextMenu.listen((event) {
      handleProtectedReaderAction(source: 'context_menu', event: event);
    });
    readerKeyDownSubscription = html.document.onKeyDown.listen((event) {
      final shouldBlock = readerProtectionPolicy.shouldBlockShortcut(
        event.key ?? '',
        controlOrMetaPressed: event.ctrlKey || event.metaKey,
      );

      if (!shouldBlock) return;

      handleProtectedReaderAction(
        source: 'keyboard_${event.key?.toLowerCase() ?? 'shortcut'}',
        event: event,
      );
    });
  }

  void updateReaderWindowActivity({
    required bool isActive,
    required String source,
  }) {
    if (readerWindowIsActive == isActive) return;

    if (mounted) {
      setState(() {
        readerWindowIsActive = isActive;
      });
    } else {
      readerWindowIsActive = isActive;
    }

    if (!isActive && readerProtectionPolicy.shouldBlurWhenInactive) {
      logReaderAction(
        action: 'reader_privacy_shield_shown',
        details: {
          'source': source,
          'pageNumber': currentPdfPage,
          'accessLevel': widget.accessLevel,
        },
      );
    }
  }

  void restoreReaderPrivacyShield(String source) {
    if (!shouldShowReaderPrivacyShield) return;

    updateReaderWindowActivity(isActive: true, source: source);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Read mode restored.')));
    logReaderAction(
      action: 'reader_privacy_shield_restored',
      details: {
        'source': source,
        'currentPdfPage': currentPdfPage,
        'accessLevel': widget.accessLevel,
      },
    );
  }

  void handleProtectedReaderAction({
    required String source,
    required html.Event event,
  }) {
    if (!canViewDocument || !readerProtectionPolicy.shouldDeterCopying) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(readerProtectionPolicy.protectedActionMessage)),
      );
    }

    logReaderAction(
      action: 'protected_reader_action_blocked',
      details: {
        'source': source,
        'pageNumber': currentPdfPage,
        'accessLevel': widget.accessLevel,
      },
    );
  }

  void openPdfPage(
    int pageNumber, {
    String? searchQuery,
    String source = 'reader_navigation',
  }) {
    final safePageNumber = pageNumber < 1 ? 1 : pageNumber;
    final nextSearchQuery = searchQuery ?? currentSearchQuery;

    if (mounted) {
      setState(() {
        currentPdfPage = safePageNumber;
        currentSearchQuery = nextSearchQuery;
      });
    } else {
      currentPdfPage = safePageNumber;
      currentSearchQuery = nextSearchQuery;
    }

    logReaderAction(
      action: 'open_pdf_page',
      details: {
        'pageNumber': safePageNumber,
        'source': source,
        'hasSearchQuery': (searchQuery ?? '').trim().isNotEmpty,
      },
    );

    if (readerProtectionPolicy.usesProtectedImageReader) {
      scrollProtectedPdfImageReaderToPage(currentPdfPage);
    } else {
      updatePdfIframeSource(
        pageNumber: currentPdfPage,
        searchQuery: currentSearchQuery,
      );
    }
    preloadNarrationTextForPage(safePageNumber);
  }

  void clearActivePdfSearch() {
    if (currentSearchQuery.trim().isEmpty) return;

    openPdfPage(
      currentPdfPage,
      searchQuery: '',
      source: 'clear_internal_pdf_search',
    );

    logReaderAction(
      action: 'clear_internal_pdf_search',
      details: {'currentPdfPage': currentPdfPage},
    );
  }

  Future<bool> goToPdfPage(int page) async {
    if (page < 1) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid page number.')),
      );
      return false;
    }

    late final int pageCount;

    try {
      pageCount = await loadPdfPageCount();
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      return false;
    }

    if (page > pageCount) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This document has only $pageCount pages.')),
      );
      return false;
    }

    openPdfPage(page, source: 'manual_page_jump');

    if (!mounted) return false;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Opened page $page of $pageCount')));

    return true;
  }

  Future<int> loadPdfPageCount() async {
    if (pdfPageCount != null) {
      return pdfPageCount!;
    }

    final response = await http
        .get(Uri.parse(widget.pdfUrl))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode >= 400) {
      throw Exception('Could not check the PDF page count.');
    }

    final document = PdfDocument(inputBytes: response.bodyBytes);

    try {
      pdfPageCount = document.pages.count;
      return pdfPageCount!;
    } finally {
      document.dispose();
    }
  }

  Future<bool> saveReadingPositionPage(int page) async {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email;

    if (user == null || userEmail == null || userEmail.isEmpty) {
      return false;
    }

    if (page < 1) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid page number.')),
      );
      return false;
    }

    late final int pageCount;

    try {
      pageCount = await loadPdfPageCount();
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      return false;
    }

    if (page > pageCount) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This document has only $pageCount pages.')),
      );
      return false;
    }

    await savedPositionRepository.save(
      ReaderSavedPositionDraft(
        userEmail: userEmail,
        pdfTitle: widget.title,
        documentKey: readerDocumentKey,
        storagePath: normalizedReaderStoragePath,
        pageNumber: page,
      ),
    );

    await logReaderAction(
      action: 'save_reading_position',
      details: {'pageNumber': page, 'pageCount': pageCount},
    );

    if (!mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reading position saved: Page $page')),
    );

    return true;
  }

  Future<String?> promptReaderBookmarkLabel({
    required int pageNumber,
    String initialLabel = '',
  }) {
    final labelController = TextEditingController(text: initialLabel);

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return PointerInterceptor(
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F1117),
            title: Text(
              initialLabel.trim().isEmpty ? 'Add Bookmark' : 'Edit Bookmark',
              style: const TextStyle(color: Colors.greenAccent),
            ),
            content: TextField(
              controller: labelController,
              autofocus: true,
              maxLength: 80,
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Label',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'Optional label for page $pageNumber',
                hintStyle: const TextStyle(color: Colors.white38),
                helperText: 'Linked to page $pageNumber',
                helperStyle: const TextStyle(color: Colors.white54),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                Navigator.of(dialogContext).pop(value.trim());
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(labelController.text.trim()),
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.greenAccent),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(labelController.dispose);
  }

  Future<void> addReaderBookmark() async {
    if (!canUseViewerTools('add_reader_bookmark')) return;

    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email;
    if (user == null || userEmail == null || userEmail.isEmpty) return;

    final page = currentPdfPage < 1 ? 1 : currentPdfPage;
    final label = await promptReaderBookmarkLabel(pageNumber: page);
    if (label == null || !mounted) return;

    late final int pageCount;

    try {
      pageCount = await loadPdfPageCount();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }

    if (page > pageCount) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This document has only $pageCount pages.')),
      );
      return;
    }

    await readerBookmarkRepository.save(
      ReaderBookmarkDraft(
        userEmail: userEmail,
        pdfTitle: widget.title,
        label: label,
        documentKey: readerDocumentKey,
        storagePath: normalizedReaderStoragePath,
        pageNumber: page,
      ),
    );

    await logReaderAction(
      action: 'add_reader_bookmark',
      details: {
        'pageNumber': page,
        'pageCount': pageCount,
        'hasLabel': label.trim().isNotEmpty,
      },
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Bookmark saved: Page $page')));
  }

  Future<void> showReaderBookmarksDialog() async {
    if (!canUseViewerTools('view_reader_bookmarks')) return;

    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email;
    if (user == null || userEmail == null || userEmail.isEmpty) return;

    await logReaderAction(action: 'view_reader_bookmarks');

    if (!mounted) return;

    final bookmarkSearchController = TextEditingController();
    var bookmarkSearchQuery = '';

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PointerInterceptor(
              child: AlertDialog(
                backgroundColor: const Color(0xFF0F1117),
                title: const Text(
                  'Reader Bookmarks',
                  style: TextStyle(color: Colors.greenAccent),
                ),
                content: SizedBox(
                  width: 420,
                  height: 520,
                  child: Column(
                    children: [
                      TextField(
                        controller: bookmarkSearchController,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.greenAccent,
                          ),
                          labelText: 'Search bookmarks',
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: 'Label or page',
                          hintStyle: const TextStyle(color: Colors.white38),
                          suffixIcon: bookmarkSearchQuery.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () {
                                    bookmarkSearchController.clear();
                                    setDialogState(() {
                                      bookmarkSearchQuery = '';
                                    });
                                  },
                                ),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            bookmarkSearchQuery = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: StreamBuilder<List<ReaderBookmark>>(
                          stream: readerBookmarkRepository.watchForDocument(
                            userEmail: userEmail,
                            pdfTitle: widget.title,
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final allBookmarks = snapshot.data!;
                            final bookmarks = ReaderBookmark.search(
                              allBookmarks,
                              bookmarkSearchQuery,
                            );

                            if (allBookmarks.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No bookmarks saved for this PDF yet.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              );
                            }

                            if (bookmarks.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No bookmarks match this search.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              );
                            }

                            return ListView.builder(
                              primary: false,
                              itemCount: bookmarks.length,
                              itemBuilder: (context, index) {
                                final bookmark = bookmarks[index];
                                final bookmarkId = bookmark.id;
                                final bookmarkPage = bookmark.pageNumber;

                                return Card(
                                  color: const Color(0xFF1A1D26),
                                  child: ListTile(
                                    onTap: () {
                                      Navigator.of(dialogContext).pop();
                                      openPdfPage(
                                        bookmarkPage,
                                        source: 'reader_bookmark',
                                      );
                                    },
                                    leading: const Icon(
                                      Icons.bookmark,
                                      color: Colors.greenAccent,
                                    ),
                                    title: Text(
                                      bookmark.displayLabel,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          'Page $bookmarkPage',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        Text(
                                          formatReaderBookmarkTime(bookmark),
                                          style: const TextStyle(
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit bookmark label',
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.greenAccent,
                                          ),
                                          onPressed: () async {
                                            final updatedLabel =
                                                await promptReaderBookmarkLabel(
                                                  pageNumber: bookmarkPage,
                                                  initialLabel: bookmark.label,
                                                );

                                            if (updatedLabel == null) return;

                                            await readerBookmarkRepository
                                                .updateLabel(
                                                  bookmarkId: bookmarkId,
                                                  label: updatedLabel,
                                                );

                                            await logReaderAction(
                                              action: 'edit_reader_bookmark',
                                              details: {
                                                'bookmarkId': bookmarkId,
                                                'pageNumber': bookmarkPage,
                                                'hasLabel': updatedLabel
                                                    .trim()
                                                    .isNotEmpty,
                                              },
                                            );

                                            if (!context.mounted) return;

                                            ScaffoldMessenger.of(
                                              context,
                                            ).hideCurrentSnackBar();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Bookmark updated',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          tooltip: 'Delete bookmark',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                          ),
                                          onPressed: () async {
                                            final confirmDelete =
                                                await showDialog<bool>(
                                                  context: context,
                                                  builder: (confirmContext) {
                                                    return PointerInterceptor(
                                                      child: AlertDialog(
                                                        backgroundColor:
                                                            const Color(
                                                              0xFF0F1117,
                                                            ),
                                                        title: const Text(
                                                          'Delete Bookmark?',
                                                          style: TextStyle(
                                                            color: Colors
                                                                .redAccent,
                                                          ),
                                                        ),
                                                        content: Text(
                                                          'Remove the bookmark for page $bookmarkPage?',
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white70,
                                                              ),
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  confirmContext,
                                                                  false,
                                                                ),
                                                            child: const Text(
                                                              'Cancel',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white70,
                                                              ),
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  confirmContext,
                                                                  true,
                                                                ),
                                                            child: const Text(
                                                              'Delete',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .redAccent,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                );

                                            if (confirmDelete != true) return;

                                            await readerBookmarkRepository
                                                .delete(bookmarkId);

                                            await logReaderAction(
                                              action: 'delete_reader_bookmark',
                                              details: {
                                                'bookmarkId': bookmarkId,
                                                'pageNumber': bookmarkPage,
                                              },
                                            );

                                            if (!context.mounted) return;

                                            ScaffoldMessenger.of(
                                              context,
                                            ).hideCurrentSnackBar();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Bookmark deleted',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Colors.greenAccent),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(bookmarkSearchController.dispose);
  }

  List<TextSpan> highlightSearchText(String text, String keyword) {
    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();

    final spans = <TextSpan>[];

    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerKeyword, start);

      if (index == -1) {
        spans.add(
          TextSpan(
            text: text.substring(start),
            style: const TextStyle(color: Colors.white70),
          ),
        );
        break;
      }

      if (index > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, index),
            style: const TextStyle(color: Colors.white70),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + keyword.length),
          style: const TextStyle(
            color: Colors.yellow,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + keyword.length;
    }

    return spans;
  }

  Future<List<Map<String, dynamic>>> searchPdfText(String keyword) async {
    final normalizedKeyword = keyword.trim().toLowerCase();

    if (normalizedKeyword.isEmpty) {
      return [];
    }

    final response = await http
        .get(Uri.parse(widget.pdfUrl))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode >= 400) {
      throw Exception('PDF text search could not load this document.');
    }

    final document = PdfDocument(inputBytes: response.bodyBytes);
    final extractor = PdfTextExtractor(document);

    try {
      final results = <Map<String, dynamic>>[];

      for (int i = 0; i < document.pages.count; i++) {
        final text = extractor.extractText(startPageIndex: i, endPageIndex: i);

        final lowerText = text.toLowerCase();
        var matchIndex = lowerText.indexOf(normalizedKeyword);
        var matchNumber = 0;

        while (matchIndex != -1) {
          matchNumber++;

          final snippetStart = matchIndex - 80 < 0 ? 0 : matchIndex - 80;
          final snippetEnd = matchIndex + 180 > text.length
              ? text.length
              : matchIndex + 180;

          final snippet = text.substring(snippetStart, snippetEnd);

          results.add({
            'pdfTitle': widget.title,
            'pdfUrl': widget.pdfUrl,
            'pageNumber': i + 1,
            'matchNumber': matchNumber,
            'text': snippet,
          });

          final nextStart = matchIndex + normalizedKeyword.length;
          matchIndex = lowerText.indexOf(normalizedKeyword, nextStart);
        }
      }

      await logReaderAction(
        action: 'internal_pdf_search',
        details: {
          'keywordLength': keyword.length,
          'resultCount': results.length,
          'pageCount': results
              .map((result) => readStoredPageNumber(result['pageNumber']))
              .toSet()
              .length,
        },
      );

      return results;
    } finally {
      document.dispose();
    }
  }

  bool canUsePremiumNarration(String attemptedAction) {
    if (narrationAccessPolicy.canChooseVoice) return true;

    logReaderAction(
      action: 'blocked_narration_feature_attempt',
      details: {
        'attemptedAction': attemptedAction,
        'narrationPlan': narrationAccessPolicy.plan.name,
      },
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(narrationAccessPolicy.upgradeMessage)),
    );
    return false;
  }

  void preloadNarrationTextForPage(int pageNumber) {
    final safePageNumber = pageNumber < 1 ? 1 : pageNumber;
    if (narrationPageTextCache.containsKey(safePageNumber)) return;

    loadNarrationTextForPage(safePageNumber).catchError((_) => '');
  }

  Future<List<int>> loadNarrationPdfBytes() async {
    final cachedFuture = narrationPdfBytesFuture;
    if (cachedFuture != null) return cachedFuture;

    final future = http
        .get(Uri.parse(widget.pdfUrl))
        .timeout(const Duration(seconds: 30))
        .then<List<int>>((response) {
          if (response.statusCode >= 400) {
            throw Exception('Narration could not load this PDF.');
          }

          return response.bodyBytes;
        });

    narrationPdfBytesFuture = future;

    try {
      return await future;
    } catch (_) {
      if (identical(narrationPdfBytesFuture, future)) {
        narrationPdfBytesFuture = null;
      }
      rethrow;
    }
  }

  Future<String> loadNarrationTextForPage(int pageNumber) async {
    final safePageNumber = pageNumber < 1 ? 1 : pageNumber;
    final cachedText = narrationPageTextCache[safePageNumber];

    if (cachedText != null) {
      return cachedText;
    }

    final document = PdfDocument(inputBytes: await loadNarrationPdfBytes());

    try {
      final pageCount = document.pages.count;

      if (safePageNumber > pageCount) {
        throw Exception('This document has only $pageCount pages.');
      }

      pdfPageCount = pageCount;

      final extractor = PdfTextExtractor(document);
      final text = extractor
          .extractText(
            startPageIndex: safePageNumber - 1,
            endPageIndex: safePageNumber - 1,
          )
          .trim();

      narrationPageTextCache[safePageNumber] = text;
      return text;
    } finally {
      document.dispose();
    }
  }

  Future<ReaderNarrationCheckpoint?> loadNarrationCheckpoint(
    int pageNumber,
  ) async {
    return narrationProgressController.load(
      context: narrationProgressContext,
      pageNumber: pageNumber,
    );
  }

  Future<_ReaderHighlightDetailsResult?> chooseReaderHighlightDetails() {
    final noteController = TextEditingController();
    var selectedColor = 'yellow';

    return showDialog<_ReaderHighlightDetailsResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PointerInterceptor(
              child: AlertDialog(
                backgroundColor: const Color(0xFF0F1117),
                title: const Text(
                  'Highlight Details',
                  style: TextStyle(color: Colors.greenAccent),
                ),
                content: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Color',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: readerHighlightColors.entries.map((entry) {
                          final colorName = entry.key;
                          final colorValue = entry.value;
                          final isSelected = selectedColor == colorName;

                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              setDialogState(() {
                                selectedColor = colorName;
                              });
                            },
                            child: Container(
                              width: 128,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.greenAccent
                                      : Colors.white24,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: colorValue,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      readerHighlightColorLabel(colorName),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: noteController,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Note',
                          labelStyle: TextStyle(color: Colors.white70),
                          hintText: 'Optional context for this highlight',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(
                        _ReaderHighlightDetailsResult(
                          color: selectedColor,
                          note: noteController.text.trim(),
                        ),
                      );
                    },
                    child: const Text(
                      'Save',
                      style: TextStyle(color: Colors.greenAccent),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(noteController.dispose);
  }

  Future<void> addReaderHighlight() async {
    if (!canUseViewerTools('add_reader_highlight')) return;

    final selectionPage = currentPdfPage;
    final selectedText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return ReaderTextSelectionDialog(
          pageNumber: selectionPage,
          pageText: loadNarrationTextForPage(selectionPage),
          title: 'Highlight Passage | Page $selectionPage',
          confirmLabel: 'Save Highlight',
          confirmIcon: Icons.border_color,
        );
      },
    );

    final trimmedSelection = selectedText?.trim() ?? '';
    if (trimmedSelection.isEmpty || !mounted) return;

    final highlightDetails = await chooseReaderHighlightDetails();
    if (highlightDetails == null || !mounted) return;

    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null || userEmail.isEmpty) return;

    await readerHighlightRepository.save(
      ReaderHighlightDraft(
        userEmail: userEmail,
        pdfTitle: widget.title,
        selectedText: trimmedSelection,
        color: normalizeReaderHighlightColor(highlightDetails.color),
        note: highlightDetails.note,
        documentKey: readerDocumentKey,
        storagePath: normalizedReaderStoragePath,
        pageNumber: selectionPage,
      ),
    );

    await logReaderAction(
      action: 'add_reader_highlight',
      details: {
        'pageNumber': selectionPage,
        'characterCount': trimmedSelection.length,
        'color': highlightDetails.color,
        'hasNote': highlightDetails.note.isNotEmpty,
      },
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Highlight saved')));
  }

  Future<void> showReaderHighlightsDialog() async {
    if (!canUseViewerTools('view_reader_highlights')) return;

    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email;
    if (user == null || userEmail == null || userEmail.isEmpty) return;

    await logReaderAction(action: 'view_reader_highlights');

    if (!mounted) return;

    final highlightSearchController = TextEditingController();
    var highlightSearchQuery = '';

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PointerInterceptor(
              child: AlertDialog(
                backgroundColor: const Color(0xFF0F1117),
                title: const Text(
                  'Reader Highlights',
                  style: TextStyle(color: Colors.greenAccent),
                ),
                content: SizedBox(
                  width: 420,
                  height: 520,
                  child: Column(
                    children: [
                      TextField(
                        controller: highlightSearchController,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.greenAccent,
                          ),
                          labelText: 'Search highlights',
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: 'Text, page, or color',
                          hintStyle: const TextStyle(color: Colors.white38),
                          suffixIcon: highlightSearchQuery.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () {
                                    highlightSearchController.clear();
                                    setDialogState(() {
                                      highlightSearchQuery = '';
                                    });
                                  },
                                ),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            highlightSearchQuery = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: StreamBuilder<List<ReaderHighlight>>(
                          stream: readerHighlightRepository.watchForDocument(
                            userEmail: userEmail,
                            pdfTitle: widget.title,
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final allHighlights = snapshot.data!;
                            final highlights = ReaderHighlight.search(
                              allHighlights,
                              highlightSearchQuery,
                            );

                            if (allHighlights.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No highlights saved for this PDF yet.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              );
                            }

                            if (highlights.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No highlights match this search.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              );
                            }

                            return ListView.builder(
                              primary: false,
                              itemCount: highlights.length,
                              itemBuilder: (context, index) {
                                final highlight = highlights[index];
                                final highlightId = highlight.id;
                                final highlightPage = highlight.pageNumber;
                                final highlightColor = readerHighlightColor(
                                  highlight.color,
                                );
                                final highlightColorLabel =
                                    highlight.displayColor;

                                return Card(
                                  color: const Color(0xFF1A1D26),
                                  child: ListTile(
                                    onTap: () {
                                      Navigator.of(dialogContext).pop();
                                      openPdfPage(
                                        highlightPage,
                                        source: 'reader_highlight',
                                      );
                                    },
                                    leading: Container(
                                      width: 14,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: highlightColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    title: Text(
                                      highlight.selectedText,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          'Page $highlightPage | $highlightColorLabel',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        Text(
                                          formatReaderHighlightTime(highlight),
                                          style: const TextStyle(
                                            color: Colors.white54,
                                          ),
                                        ),
                                        if (highlight.hasNote) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            highlight.note,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: highlight.hasNote
                                              ? 'Edit highlight note'
                                              : 'Add highlight note',
                                          icon: const Icon(
                                            Icons.edit_note,
                                            color: Colors.greenAccent,
                                          ),
                                          onPressed: () async {
                                            final noteController =
                                                TextEditingController(
                                                  text: highlight.note,
                                                );

                                            final updatedNote = await showDialog<String>(
                                              context: context,
                                              builder: (editContext) {
                                                return PointerInterceptor(
                                                  child: AlertDialog(
                                                    backgroundColor:
                                                        const Color(0xFF0F1117),
                                                    title: const Text(
                                                      'Highlight Note',
                                                      style: TextStyle(
                                                        color:
                                                            Colors.greenAccent,
                                                      ),
                                                    ),
                                                    content: TextField(
                                                      controller:
                                                          noteController,
                                                      autofocus: true,
                                                      maxLines: 5,
                                                      textInputAction:
                                                          TextInputAction
                                                              .newline,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                      decoration: const InputDecoration(
                                                        hintText:
                                                            'Add context for this highlight',
                                                        hintStyle: TextStyle(
                                                          color: Colors.white54,
                                                        ),
                                                        border:
                                                            OutlineInputBorder(),
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              editContext,
                                                            ),
                                                        child: const Text(
                                                          'Cancel',
                                                          style: TextStyle(
                                                            color:
                                                                Colors.white70,
                                                          ),
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.pop(
                                                            editContext,
                                                            noteController.text
                                                                .trim(),
                                                          );
                                                        },
                                                        child: const Text(
                                                          'Save',
                                                          style: TextStyle(
                                                            color: Colors
                                                                .greenAccent,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            );

                                            noteController.dispose();

                                            if (updatedNote == null) return;

                                            await readerHighlightRepository
                                                .updateNote(
                                                  highlightId: highlightId,
                                                  note: updatedNote,
                                                );

                                            await logReaderAction(
                                              action:
                                                  'edit_reader_highlight_note',
                                              details: {
                                                'highlightId': highlightId,
                                                'pageNumber': highlightPage,
                                                'hasNote':
                                                    updatedNote.isNotEmpty,
                                              },
                                            );

                                            if (!context.mounted) return;

                                            ScaffoldMessenger.of(
                                              context,
                                            ).hideCurrentSnackBar();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Highlight note updated',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          tooltip: 'Delete highlight',
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.redAccent,
                                          ),
                                          onPressed: () async {
                                            final confirmDelete =
                                                await showDialog<bool>(
                                                  context: context,
                                                  builder: (confirmContext) {
                                                    return PointerInterceptor(
                                                      child: AlertDialog(
                                                        backgroundColor:
                                                            const Color(
                                                              0xFF0F1117,
                                                            ),
                                                        title: const Text(
                                                          'Delete Highlight?',
                                                          style: TextStyle(
                                                            color: Colors
                                                                .redAccent,
                                                          ),
                                                        ),
                                                        content: Text(
                                                          'Remove the saved highlight from page $highlightPage?',
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white70,
                                                              ),
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  confirmContext,
                                                                  false,
                                                                ),
                                                            child: const Text(
                                                              'Cancel',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white70,
                                                              ),
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  confirmContext,
                                                                  true,
                                                                ),
                                                            child: const Text(
                                                              'Delete',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .redAccent,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                );

                                            if (confirmDelete != true) return;

                                            await readerHighlightRepository
                                                .delete(highlightId);

                                            await logReaderAction(
                                              action: 'delete_reader_highlight',
                                              details: {
                                                'highlightId': highlightId,
                                                'pageNumber': highlightPage,
                                              },
                                            );

                                            if (!context.mounted) return;

                                            ScaffoldMessenger.of(
                                              context,
                                            ).hideCurrentSnackBar();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Highlight deleted',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Colors.greenAccent),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(highlightSearchController.dispose);
  }

  Future<void> showReaderWorkspaceDialog() async {
    if (!canUseViewerTools('view_reader_workspace')) return;

    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email;
    if (user == null || userEmail == null || userEmail.isEmpty) return;

    await logReaderAction(action: 'view_reader_workspace');

    if (!mounted) return;

    final workspaceSearchController = TextEditingController();
    var workspaceSearchQuery = '';
    var workspaceHighlightColorFilter = 'All';
    var workspaceNoteCategoryFilter = 'All';

    List<ReaderNote> filterWorkspaceNotes(Iterable<ReaderNote> notes) {
      return ReaderWorkspaceFilters.filterNotes(
        notes: notes,
        query: workspaceSearchQuery,
        categoryFilter: workspaceNoteCategoryFilter,
      );
    }

    List<ReaderHighlight> filterWorkspaceHighlights(
      Iterable<ReaderHighlight> highlights,
    ) {
      return ReaderWorkspaceFilters.filterHighlights(
        highlights: highlights,
        query: workspaceSearchQuery,
        colorFilter: workspaceHighlightColorFilter,
      );
    }

    Widget emptyWorkspaceMessage(
      String message, {
      VoidCallback? onClearFilters,
      String clearLabel = 'Clear search',
    }) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            if (onClearFilters != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.clear, size: 18),
                label: Text(clearLabel),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.greenAccent,
                ),
              ),
            ],
          ],
        ),
      );
    }

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void clearWorkspaceFilters() {
              workspaceSearchController.clear();
              setDialogState(() {
                workspaceSearchQuery = '';
                workspaceHighlightColorFilter = 'All';
                workspaceNoteCategoryFilter = 'All';
              });
            }

            List<String> activeWorkspaceFilterLabels() {
              return ReaderWorkspaceFilters.activeFilterLabels(
                query: workspaceSearchQuery,
                highlightColorFilter: workspaceHighlightColorFilter,
                noteCategoryFilter: workspaceNoteCategoryFilter,
              );
            }

            Widget workspaceActiveFilterBar(List<String> labels) {
              if (labels.isEmpty) return const SizedBox.shrink();

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...labels.map(
                    (label) => Chip(
                      label: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: const Color(0xFF151821),
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: clearWorkspaceFilters,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear all'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.greenAccent,
                    ),
                  ),
                ],
              );
            }

            Widget workspaceSummaryCard({
              required IconData icon,
              required String title,
              required String countLabel,
              required String subtitle,
              required int tabIndex,
            }) {
              return Builder(
                builder: (cardContext) {
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Card(
                      color: const Color(0xFF1A1D26),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        hoverColor: Colors.greenAccent.withValues(alpha: 0.08),
                        splashColor: Colors.greenAccent.withValues(alpha: 0.12),
                        onTap: () {
                          DefaultTabController.of(
                            cardContext,
                          ).animateTo(tabIndex);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(icon, color: Colors.greenAccent, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      countLabel,
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.white38,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }

            Widget workspaceSummaryStreamCard<T>({
              required Stream<List<T>> stream,
              required IconData icon,
              required String title,
              required String emptySubtitle,
              required String Function(List<T> items) filledSubtitleBuilder,
              required int tabIndex,
              List<T> Function(List<T> items)? filterBuilder,
              bool hasActiveFilter = false,
            }) {
              return StreamBuilder<List<T>>(
                stream: stream,
                builder: (context, snapshot) {
                  final allItems = snapshot.data;
                  final items = allItems == null
                      ? null
                      : filterBuilder?.call(allItems) ?? allItems;
                  final count = items?.length;
                  final hasActiveWorkspaceFilter =
                      ReaderWorkspaceFilters.hasActiveFilters(
                        query: workspaceSearchQuery,
                        highlightColorFilter: workspaceHighlightColorFilter,
                        noteCategoryFilter: workspaceNoteCategoryFilter,
                      );
                  final subtitle = allItems == null
                      ? 'Checking saved items...'
                      : allItems.isEmpty
                      ? emptySubtitle
                      : hasActiveWorkspaceFilter && items!.isEmpty
                      ? 'No matching items in this section.'
                      : filledSubtitleBuilder(items!);

                  return workspaceSummaryCard(
                    icon: icon,
                    title: title,
                    countLabel: count == null
                        ? '...'
                        : ReaderWorkspaceFilters.filteredCountLabel(
                            visibleCount: count,
                            totalCount: allItems?.length ?? count,
                            hasActiveFilter: hasActiveFilter,
                          ),
                    subtitle: subtitle,
                    tabIndex: tabIndex,
                  );
                },
              );
            }

            Widget workspaceTab({
              required IconData icon,
              required String label,
              int? count,
            }) {
              final text = count == null ? label : '$label ($count)';

              return Tab(icon: Icon(icon), text: text);
            }

            Widget workspaceCountTab<T>({
              required Stream<List<T>> stream,
              required IconData icon,
              required String label,
              int Function(List<T> items)? countBuilder,
            }) {
              return StreamBuilder<List<T>>(
                stream: stream,
                builder: (context, snapshot) {
                  final items = snapshot.data;
                  final count = items == null
                      ? null
                      : countBuilder?.call(items) ?? items.length;

                  return workspaceTab(icon: icon, label: label, count: count);
                },
              );
            }

            Widget workspaceClickableCard({required Widget child}) {
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Card(color: const Color(0xFF1A1D26), child: child),
              );
            }

            String workspacePreview(String value, {int maximumLength = 44}) {
              final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
              if (cleaned.length <= maximumLength) return cleaned;

              return '${cleaned.substring(0, maximumLength).trimRight()}...';
            }

            Widget overviewTab() {
              final activeFilterLabels = activeWorkspaceFilterLabels();

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: const Color(0xFF151821),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.menu_book_outlined,
                              color: Colors.greenAccent,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    pdfPageCount == null
                                        ? 'Tracked page: $currentPdfPage'
                                        : 'Tracked page: $currentPdfPage of $pdfPageCount',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (activeFilterLabels.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      workspaceActiveFilterBar(activeFilterLabels),
                    ],
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = constraints.maxWidth >= 520
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child:
                                  workspaceSummaryStreamCard<
                                    ReaderSavedPosition
                                  >(
                                    stream: savedPositionRepository
                                        .watchForDocument(
                                          userEmail: userEmail,
                                          pdfTitle: widget.title,
                                        ),
                                    icon: Icons.history,
                                    title: 'Positions',
                                    emptySubtitle: 'No saved positions yet',
                                    filledSubtitleBuilder: (positions) =>
                                        'Latest: page ${positions.first.pageNumber}',
                                    filterBuilder: (positions) =>
                                        ReaderWorkspaceFilters.filterPositions(
                                          positions,
                                          workspaceSearchQuery,
                                        ),
                                    hasActiveFilter: workspaceSearchQuery
                                        .trim()
                                        .isNotEmpty,
                                    tabIndex: 1,
                                  ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: workspaceSummaryStreamCard<ReaderBookmark>(
                                stream: readerBookmarkRepository
                                    .watchForDocument(
                                      userEmail: userEmail,
                                      pdfTitle: widget.title,
                                    ),
                                icon: Icons.bookmark,
                                title: 'Bookmarks',
                                emptySubtitle: 'No bookmarks yet',
                                filledSubtitleBuilder: (bookmarks) =>
                                    'Latest: ${workspacePreview(bookmarks.first.displayLabel)}',
                                filterBuilder: (bookmarks) =>
                                    ReaderBookmark.search(
                                      bookmarks,
                                      workspaceSearchQuery,
                                    ),
                                hasActiveFilter: workspaceSearchQuery
                                    .trim()
                                    .isNotEmpty,
                                tabIndex: 2,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: workspaceSummaryStreamCard<ReaderHighlight>(
                                stream: readerHighlightRepository
                                    .watchForDocument(
                                      userEmail: userEmail,
                                      pdfTitle: widget.title,
                                    ),
                                icon: Icons.border_color,
                                title: 'Highlights',
                                emptySubtitle: 'No highlights yet',
                                filledSubtitleBuilder: (highlights) =>
                                    'Latest: ${workspacePreview(highlights.first.selectedText)}',
                                filterBuilder: filterWorkspaceHighlights,
                                hasActiveFilter:
                                    workspaceSearchQuery.trim().isNotEmpty ||
                                    workspaceHighlightColorFilter != 'All',
                                tabIndex: 3,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: workspaceSummaryStreamCard<ReaderNote>(
                                stream: readerNoteRepository.watchForDocument(
                                  userEmail: userEmail,
                                  pdfTitle: widget.title,
                                ),
                                icon: Icons.note_alt,
                                title: 'Notes',
                                emptySubtitle: 'No notes yet',
                                filledSubtitleBuilder: (notes) =>
                                    'Latest: ${workspacePreview(notes.first.note)}',
                                filterBuilder: filterWorkspaceNotes,
                                hasActiveFilter:
                                    workspaceSearchQuery.trim().isNotEmpty ||
                                    workspaceNoteCategoryFilter != 'All',
                                tabIndex: 4,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            }

            Widget positionsTab() {
              return StreamBuilder<List<ReaderSavedPosition>>(
                stream: savedPositionRepository.watchForDocument(
                  userEmail: userEmail,
                  pdfTitle: widget.title,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allPositions = snapshot.data!;
                  final positions = ReaderWorkspaceFilters.filterPositions(
                    allPositions,
                    workspaceSearchQuery,
                  );

                  if (allPositions.isEmpty) {
                    return emptyWorkspaceMessage(
                      'No saved positions for this PDF yet.',
                    );
                  }

                  if (positions.isEmpty) {
                    return emptyWorkspaceMessage(
                      'No saved positions match these filters.',
                      onClearFilters: clearWorkspaceFilters,
                      clearLabel: 'Clear all filters',
                    );
                  }

                  return ListView.builder(
                    primary: false,
                    itemCount: positions.length,
                    itemBuilder: (context, index) {
                      final position = positions[index];
                      final page = position.pageNumber;

                      return workspaceClickableCard(
                        child: ListTile(
                          hoverColor: Colors.greenAccent.withValues(
                            alpha: 0.08,
                          ),
                          leading: const Icon(
                            Icons.history,
                            color: Colors.greenAccent,
                          ),
                          title: Text(
                            'Page $page',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'Saved: ${formatSavedPositionTime(position.createdAt)}',
                            style: const TextStyle(color: Colors.white54),
                          ),
                          trailing: const Icon(
                            Icons.open_in_new,
                            color: Colors.greenAccent,
                            size: 18,
                          ),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            openPdfPage(
                              page,
                              source: 'reader_workspace_position',
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );
            }

            Widget bookmarksTab() {
              return StreamBuilder<List<ReaderBookmark>>(
                stream: readerBookmarkRepository.watchForDocument(
                  userEmail: userEmail,
                  pdfTitle: widget.title,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allBookmarks = snapshot.data!;
                  final bookmarks = ReaderBookmark.search(
                    allBookmarks,
                    workspaceSearchQuery,
                  );

                  if (allBookmarks.isEmpty) {
                    return emptyWorkspaceMessage(
                      'No bookmarks saved for this PDF yet.',
                    );
                  }

                  if (bookmarks.isEmpty) {
                    return emptyWorkspaceMessage(
                      'No bookmarks match these filters.',
                      onClearFilters: clearWorkspaceFilters,
                      clearLabel: 'Clear all filters',
                    );
                  }

                  return ListView.builder(
                    primary: false,
                    itemCount: bookmarks.length,
                    itemBuilder: (context, index) {
                      final bookmark = bookmarks[index];
                      final page = bookmark.pageNumber;

                      return workspaceClickableCard(
                        child: ListTile(
                          hoverColor: Colors.greenAccent.withValues(
                            alpha: 0.08,
                          ),
                          leading: const Icon(
                            Icons.bookmark,
                            color: Colors.greenAccent,
                          ),
                          title: Text(
                            bookmark.displayLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Page $page',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Text(
                                formatReaderBookmarkTime(bookmark),
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                          trailing: const Icon(
                            Icons.open_in_new,
                            color: Colors.greenAccent,
                            size: 18,
                          ),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            openPdfPage(
                              page,
                              source: 'reader_workspace_bookmark',
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );
            }

            Widget highlightsTab() {
              return StreamBuilder<List<ReaderHighlight>>(
                stream: readerHighlightRepository.watchForDocument(
                  userEmail: userEmail,
                  pdfTitle: widget.title,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allHighlights = snapshot.data!;
                  final highlights = filterWorkspaceHighlights(allHighlights);

                  if (allHighlights.isEmpty) {
                    return emptyWorkspaceMessage(
                      'No highlights saved for this PDF yet.',
                    );
                  }

                  return Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: workspaceHighlightColorFilter,
                        dropdownColor: const Color(0xFF1A1D26),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Highlight color',
                          labelStyle: TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(),
                        ),
                        items:
                            [
                                  'All',
                                  ...readerHighlightColors.keys.map(
                                    readerHighlightColorLabel,
                                  ),
                                ]
                                .map(
                                  (color) => DropdownMenuItem<String>(
                                    value: color,
                                    child: Text(color),
                                  ),
                                )
                                .toList(),
                        onChanged: (color) {
                          if (color == null) return;
                          setDialogState(() {
                            workspaceHighlightColorFilter = color;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: highlights.isEmpty
                            ? emptyWorkspaceMessage(
                                'No highlights match these filters.',
                                onClearFilters: clearWorkspaceFilters,
                                clearLabel: 'Clear highlight filters',
                              )
                            : ListView.builder(
                                primary: false,
                                itemCount: highlights.length,
                                itemBuilder: (context, index) {
                                  final highlight = highlights[index];
                                  final page = highlight.pageNumber;

                                  return workspaceClickableCard(
                                    child: ListTile(
                                      hoverColor: Colors.greenAccent.withValues(
                                        alpha: 0.08,
                                      ),
                                      leading: Container(
                                        width: 14,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: readerHighlightColor(
                                            highlight.color,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        highlight.selectedText,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(
                                            'Page $page | ${highlight.displayColor}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                          Text(
                                            formatReaderHighlightTime(
                                              highlight,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.white54,
                                            ),
                                          ),
                                          if (highlight.hasNote) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              highlight.note,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      trailing: const Icon(
                                        Icons.open_in_new,
                                        color: Colors.greenAccent,
                                        size: 18,
                                      ),
                                      onTap: () {
                                        Navigator.of(dialogContext).pop();
                                        openPdfPage(
                                          page,
                                          source: 'reader_workspace_highlight',
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            }

            Widget notesTab() {
              return StreamBuilder<List<ReaderNote>>(
                stream: readerNoteRepository.watchForDocument(
                  userEmail: userEmail,
                  pdfTitle: widget.title,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allNotes = snapshot.data!;
                  final notes = filterWorkspaceNotes(allNotes);

                  if (allNotes.isEmpty) {
                    return emptyWorkspaceMessage(
                      'No notes saved for this PDF yet.',
                    );
                  }

                  return Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: workspaceNoteCategoryFilter,
                        dropdownColor: const Color(0xFF1A1D26),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Note category',
                          labelStyle: TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(),
                        ),
                        items: ['All', ...readerNoteCategories]
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (category) {
                          if (category == null) return;
                          setDialogState(() {
                            workspaceNoteCategoryFilter = category;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: notes.isEmpty
                            ? emptyWorkspaceMessage(
                                'No notes match these filters.',
                                onClearFilters: clearWorkspaceFilters,
                                clearLabel: 'Clear note filters',
                              )
                            : ListView.builder(
                                primary: false,
                                itemCount: notes.length,
                                itemBuilder: (context, index) {
                                  final note = notes[index];
                                  final page = note.pageNumber;

                                  return workspaceClickableCard(
                                    child: ListTile(
                                      hoverColor: Colors.greenAccent.withValues(
                                        alpha: 0.08,
                                      ),
                                      leading: const Icon(
                                        Icons.note_alt_outlined,
                                        color: Colors.greenAccent,
                                      ),
                                      title: Text(
                                        note.note,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(
                                            'Page $page | ${note.displayCategory}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                          Text(
                                            formatReaderNoteTime(note),
                                            style: const TextStyle(
                                              color: Colors.white54,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: const Icon(
                                        Icons.open_in_new,
                                        color: Colors.greenAccent,
                                        size: 18,
                                      ),
                                      onTap: () {
                                        Navigator.of(dialogContext).pop();
                                        openPdfPage(
                                          page,
                                          source: 'reader_workspace_note',
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            }

            return PointerInterceptor(
              child: DefaultTabController(
                length: 5,
                child: AlertDialog(
                  backgroundColor: const Color(0xFF0F1117),
                  title: const Text(
                    'Reader Workspace',
                    style: TextStyle(color: Colors.greenAccent),
                  ),
                  content: SizedBox(
                    width: 620,
                    height: 560,
                    child: Column(
                      children: [
                        TextField(
                          controller: workspaceSearchController,
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.greenAccent,
                            ),
                            labelText: 'Search reader workspace',
                            labelStyle: const TextStyle(color: Colors.white70),
                            hintText: 'Page, label, note, or highlighted text',
                            hintStyle: const TextStyle(color: Colors.white38),
                            suffixIcon: workspaceSearchQuery.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.white54,
                                    ),
                                    onPressed: () {
                                      workspaceSearchController.clear();
                                      setDialogState(() {
                                        workspaceSearchQuery = '';
                                      });
                                    },
                                  ),
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              workspaceSearchQuery = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TabBar(
                          isScrollable: true,
                          labelColor: Colors.greenAccent,
                          unselectedLabelColor: Colors.white54,
                          indicatorColor: Colors.greenAccent,
                          tabs: [
                            const Tab(
                              icon: Icon(Icons.dashboard_customize_outlined),
                              text: 'Overview',
                            ),
                            workspaceCountTab<ReaderSavedPosition>(
                              stream: savedPositionRepository.watchForDocument(
                                userEmail: userEmail,
                                pdfTitle: widget.title,
                              ),
                              icon: Icons.history,
                              label: 'Positions',
                              countBuilder: (positions) =>
                                  ReaderWorkspaceFilters.filterPositions(
                                    positions,
                                    workspaceSearchQuery,
                                  ).length,
                            ),
                            workspaceCountTab<ReaderBookmark>(
                              stream: readerBookmarkRepository.watchForDocument(
                                userEmail: userEmail,
                                pdfTitle: widget.title,
                              ),
                              icon: Icons.bookmark,
                              label: 'Bookmarks',
                              countBuilder: (bookmarks) =>
                                  ReaderBookmark.search(
                                    bookmarks,
                                    workspaceSearchQuery,
                                  ).length,
                            ),
                            workspaceCountTab<ReaderHighlight>(
                              stream: readerHighlightRepository
                                  .watchForDocument(
                                    userEmail: userEmail,
                                    pdfTitle: widget.title,
                                  ),
                              icon: Icons.border_color,
                              label: 'Highlights',
                              countBuilder: (highlights) =>
                                  filterWorkspaceHighlights(highlights).length,
                            ),
                            workspaceCountTab<ReaderNote>(
                              stream: readerNoteRepository.watchForDocument(
                                userEmail: userEmail,
                                pdfTitle: widget.title,
                              ),
                              icon: Icons.note_alt,
                              label: 'Notes',
                              countBuilder: (notes) =>
                                  filterWorkspaceNotes(notes).length,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: TabBarView(
                            children: [
                              overviewTab(),
                              positionsTab(),
                              bookmarksTab(),
                              highlightsTab(),
                              notesTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Colors.greenAccent),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(workspaceSearchController.dispose);
  }

  Future<void> showManualPageJumpDialog() async {
    if (!canUseViewerTools('manual_page_jump')) return;

    await logReaderAction(
      action: 'open_manual_page_jump_dialog',
      details: {'currentPdfPage': currentPdfPage},
    );

    if (!mounted) return;

    final pageController = TextEditingController(
      text: currentPdfPage.toString(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        Future<void> submitPageJump() async {
          final page = int.tryParse(pageController.text.trim()) ?? 0;
          final opened = await goToPdfPage(page);

          if (!dialogContext.mounted) return;
          if (opened) Navigator.pop(dialogContext);
        }

        return PointerInterceptor(
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F1117),
            title: const Text(
              'Go to Page',
              style: TextStyle(color: Colors.greenAccent),
            ),
            content: PointerInterceptor(
              child: TextField(
                controller: pageController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofocus: true,
                onSubmitted: (_) => submitPageJump(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Page number',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'Enter page number',
                  hintStyle: const TextStyle(color: Colors.white54),
                  helperText: pdfPageCount == null
                      ? 'Tracked page: $currentPdfPage'
                      : 'Tracked page: $currentPdfPage of $pdfPageCount',
                  helperStyle: const TextStyle(color: Colors.white54),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
              TextButton(
                onPressed: submitPageJump,
                child: const Text(
                  'Open',
                  style: TextStyle(color: Colors.greenAccent),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(pageController.dispose);
  }

  Future<void> showSaveReadingPositionDialog() async {
    if (!canUseViewerTools('open_save_reading_position_dialog')) return;

    await logReaderAction(
      action: 'open_save_reading_position_dialog',
      details: {'currentPdfPage': currentPdfPage},
    );

    if (!mounted) return;

    final pageController = TextEditingController(
      text: currentPdfPage.toString(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        Future<void> submitTypedSave() async {
          if (!canUseViewerTools('save_reading_position')) return;

          final page = int.tryParse(pageController.text.trim()) ?? 0;
          final saved = await saveReadingPositionPage(page);

          if (!dialogContext.mounted) return;
          if (saved) Navigator.pop(dialogContext);
        }

        return PointerInterceptor(
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F1117),
            title: const Text(
              'Save Current Position',
              style: TextStyle(color: Colors.greenAccent),
            ),
            content: PointerInterceptor(
              child: TextField(
                controller: pageController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofocus: true,
                onSubmitted: (_) => submitTypedSave(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Page to save',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'Page number',
                  hintStyle: const TextStyle(color: Colors.white54),
                  helperText: pdfPageCount == null
                      ? 'Current page is prefilled: $currentPdfPage'
                      : 'Current page is prefilled: $currentPdfPage of $pdfPageCount',
                  suffixText: 'Enter saves',
                  helperStyle: const TextStyle(color: Colors.white54),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
              TextButton(
                onPressed: submitTypedSave,
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.greenAccent),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(pageController.dispose);
  }

  Future<void> showSavedReadingPositionsDialog() async {
    if (!canUseViewerTools('view_saved_reading_positions')) return;

    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email;
    if (user == null || userEmail == null || userEmail.isEmpty) return;

    await logReaderAction(action: 'view_saved_reading_positions');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return PointerInterceptor(
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F1117),
            title: const Text(
              'Saved Positions',
              style: TextStyle(color: Colors.greenAccent),
            ),
            content: PointerInterceptor(
              child: SizedBox(
                width: 400,
                height: 400,
                child: StreamBuilder<List<ReaderSavedPosition>>(
                  stream: savedPositionRepository.watchForDocument(
                    userEmail: userEmail,
                    pdfTitle: widget.title,
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final positions = snapshot.data!;

                    if (positions.isEmpty) {
                      return const Center(
                        child: Text(
                          'No saved positions for this PDF yet.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: positions.length,
                      itemBuilder: (context, index) {
                        final position = positions[index];
                        final positionId = position.id;
                        final page = position.pageNumber;
                        final savedAt = formatSavedPositionTime(
                          position.createdAt,
                        );

                        return Card(
                          color: const Color(0xFF1A1D26),
                          child: ListTile(
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              openPdfPage(
                                page,
                                source: 'saved_reading_position',
                              );
                            },
                            title: Text(
                              'Page $page',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'Saved: $savedAt',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: IconButton(
                              tooltip: 'Delete saved position',
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              onPressed: () async {
                                final confirmDelete = await showDialog<bool>(
                                  context: context,
                                  builder: (confirmContext) {
                                    return PointerInterceptor(
                                      child: AlertDialog(
                                        backgroundColor: const Color(
                                          0xFF0F1117,
                                        ),
                                        title: const Text(
                                          'Delete Saved Position?',
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                        content: Text(
                                          'Remove the saved position for page $page?',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                              confirmContext,
                                              false,
                                            ),
                                            child: const Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                              confirmContext,
                                              true,
                                            ),
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );

                                if (confirmDelete != true) return;

                                await savedPositionRepository.delete(
                                  positionId,
                                );

                                await logReaderAction(
                                  action: 'delete_reading_position',
                                  details: {
                                    'positionId': positionId,
                                    'pageNumber': page,
                                  },
                                );

                                if (!mounted) return;

                                ScaffoldMessenger.of(
                                  context,
                                ).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Saved position removed: Page $page',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            actions: [
              PointerInterceptor(
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.greenAccent),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> addReaderNote() async {
    if (!canUseViewerTools('add_reader_note')) return;

    final noteController = TextEditingController();
    var selectedCategory = readerNoteCategories.first;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PointerInterceptor(
              child: AlertDialog(
                backgroundColor: const Color(0xFF0F1117),
                title: const Text(
                  'Add Note',
                  style: TextStyle(color: Colors.greenAccent),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      dropdownColor: const Color(0xFF1A1D26),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(),
                      ),
                      items: readerNoteCategories
                          .map(
                            (category) => DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: (category) {
                        if (category == null) return;
                        setDialogState(() {
                          selectedCategory = category;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      autofocus: true,
                      controller: noteController,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Note',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'Write a note for this PDF',
                        hintStyle: const TextStyle(color: Colors.white54),
                        helperText: 'Linked to page $currentPdfPage',
                        helperStyle: const TextStyle(color: Colors.white54),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final noteText = noteController.text.trim();

                      if (noteText.isEmpty) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Write a note before saving.'),
                          ),
                        );
                        return;
                      }

                      final userEmail =
                          FirebaseAuth.instance.currentUser?.email;
                      if (userEmail == null || userEmail.isEmpty) return;

                      await readerNoteRepository.save(
                        ReaderNoteDraft(
                          userEmail: userEmail,
                          pdfTitle: widget.title,
                          note: noteText,
                          documentKey: readerDocumentKey,
                          storagePath: normalizedReaderStoragePath,
                          category: normalizeReaderNoteCategory(
                            selectedCategory,
                          ),
                          pageNumber: currentPdfPage,
                        ),
                      );

                      await logReaderAction(
                        action: 'add_reader_note',
                        details: {
                          'noteLength': noteText.length,
                          'pageNumber': currentPdfPage,
                          'category': selectedCategory,
                        },
                      );

                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Note saved successfully'),
                        ),
                      );
                    },
                    child: const Text(
                      'Save',
                      style: TextStyle(color: Colors.greenAccent),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(noteController.dispose);
  }

  Future<void> showReaderNotesDialog() async {
    if (!canUseViewerTools('view_reader_notes')) return;

    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email;
    if (user == null || userEmail == null || userEmail.isEmpty) return;

    await logReaderAction(action: 'view_reader_notes');

    if (!mounted) return;

    final noteSearchController = TextEditingController();
    var noteSearchQuery = '';
    var noteCategoryFilter = 'All';

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PointerInterceptor(
              child: AlertDialog(
                backgroundColor: const Color(0xFF0F1117),
                title: const Text(
                  'Reader Notes',
                  style: TextStyle(color: Colors.greenAccent),
                ),
                content: SizedBox(
                  width: 420,
                  height: 540,
                  child: Column(
                    children: [
                      TextField(
                        controller: noteSearchController,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.greenAccent,
                          ),
                          labelText: 'Search notes',
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: 'Text, page, color, category',
                          hintStyle: const TextStyle(color: Colors.white38),
                          suffixIcon: noteSearchQuery.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () {
                                    noteSearchController.clear();
                                    setDialogState(() {
                                      noteSearchQuery = '';
                                    });
                                  },
                                ),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            noteSearchQuery = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: noteCategoryFilter,
                        dropdownColor: const Color(0xFF1A1D26),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          labelStyle: TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(),
                        ),
                        items: ['All', ...readerNoteCategories]
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (category) {
                          if (category == null) return;
                          setDialogState(() {
                            noteCategoryFilter = category;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: StreamBuilder<List<ReaderNote>>(
                          stream: readerNoteRepository.watchForDocument(
                            userEmail: userEmail,
                            pdfTitle: widget.title,
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final allNotes = snapshot.data!;
                            final matchingNotes = ReaderNote.search(
                              allNotes,
                              noteSearchQuery,
                            );
                            final notes = noteCategoryFilter == 'All'
                                ? matchingNotes
                                : matchingNotes
                                      .where(
                                        (note) =>
                                            note.displayCategory ==
                                            noteCategoryFilter,
                                      )
                                      .toList();

                            if (allNotes.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No notes saved for this PDF yet.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              );
                            }

                            if (notes.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No notes match this search.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              );
                            }

                            return ListView.builder(
                              primary: false,
                              itemCount: notes.length,
                              itemBuilder: (context, index) {
                                final note = notes[index];
                                final noteId = note.id;
                                final notePage = note.pageNumber;

                                return Card(
                                  color: const Color(0xFF1A1D26),
                                  child: ListTile(
                                    onTap: () {
                                      Navigator.of(dialogContext).pop();
                                      openPdfPage(
                                        notePage,
                                        source: 'reader_note',
                                      );
                                    },
                                    title: Text(
                                      note.note,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          'Page $notePage | ${note.displayCategory}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        Text(
                                          formatReaderNoteTime(note),
                                          style: const TextStyle(
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit note',
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.greenAccent,
                                          ),
                                          onPressed: () async {
                                            final editController =
                                                TextEditingController(
                                                  text: note.note,
                                                );
                                            var selectedEditCategory =
                                                normalizeReaderNoteCategory(
                                                  note.category,
                                                );

                                            final updatedNote = await showDialog<_ReaderNoteEditResult>(
                                              context: context,
                                              builder: (editContext) {
                                                return StatefulBuilder(
                                                  builder: (context, setEditState) {
                                                    return PointerInterceptor(
                                                      child: AlertDialog(
                                                        backgroundColor:
                                                            const Color(
                                                              0xFF0F1117,
                                                            ),
                                                        title: const Text(
                                                          'Edit Note',
                                                          style: TextStyle(
                                                            color: Colors
                                                                .greenAccent,
                                                          ),
                                                        ),
                                                        content: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              'Linked page: $notePage',
                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white70,
                                                                  ),
                                                            ),
                                                            const SizedBox(
                                                              height: 12,
                                                            ),
                                                            DropdownButtonFormField<
                                                              String
                                                            >(
                                                              initialValue:
                                                                  selectedEditCategory,
                                                              dropdownColor:
                                                                  const Color(
                                                                    0xFF1A1D26,
                                                                  ),
                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                              decoration: const InputDecoration(
                                                                labelText:
                                                                    'Category',
                                                                labelStyle: TextStyle(
                                                                  color: Colors
                                                                      .white70,
                                                                ),
                                                                border:
                                                                    OutlineInputBorder(),
                                                              ),
                                                              items: readerNoteCategories
                                                                  .map(
                                                                    (
                                                                      category,
                                                                    ) => DropdownMenuItem<String>(
                                                                      value:
                                                                          category,
                                                                      child: Text(
                                                                        category,
                                                                      ),
                                                                    ),
                                                                  )
                                                                  .toList(),
                                                              onChanged: (category) {
                                                                if (category ==
                                                                    null) {
                                                                  return;
                                                                }
                                                                setEditState(() {
                                                                  selectedEditCategory =
                                                                      category;
                                                                });
                                                              },
                                                            ),
                                                            const SizedBox(
                                                              height: 12,
                                                            ),
                                                            TextField(
                                                              controller:
                                                                  editController,
                                                              maxLines: 6,
                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                              decoration: const InputDecoration(
                                                                border:
                                                                    OutlineInputBorder(),
                                                                hintText:
                                                                    'Edit your note...',
                                                                hintStyle: TextStyle(
                                                                  color: Colors
                                                                      .white54,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  editContext,
                                                                ),
                                                            child: const Text(
                                                              'Cancel',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white70,
                                                              ),
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () {
                                                              Navigator.pop(
                                                                editContext,
                                                                _ReaderNoteEditResult(
                                                                  note: editController
                                                                      .text
                                                                      .trim(),
                                                                  category:
                                                                      selectedEditCategory,
                                                                ),
                                                              );
                                                            },
                                                            child: const Text(
                                                              'Save',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .greenAccent,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                            );

                                            editController.dispose();

                                            if (updatedNote == null) return;

                                            if (updatedNote.note.isEmpty) {
                                              if (!context.mounted) return;

                                              ScaffoldMessenger.of(
                                                context,
                                              ).hideCurrentSnackBar();
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Write a note before saving changes.',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            await readerNoteRepository.updateNote(
                                              noteId: noteId,
                                              note: updatedNote.note,
                                              category:
                                                  normalizeReaderNoteCategory(
                                                    updatedNote.category,
                                                  ),
                                            );

                                            await logReaderAction(
                                              action: 'edit_reader_note',
                                              details: {
                                                'noteId': noteId,
                                                'noteLength':
                                                    updatedNote.note.length,
                                                'pageNumber': notePage,
                                                'category':
                                                    updatedNote.category,
                                              },
                                            );

                                            if (!context.mounted) return;

                                            ScaffoldMessenger.of(
                                              context,
                                            ).hideCurrentSnackBar();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Note updated successfully',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          tooltip: 'Delete note',
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.redAccent,
                                          ),
                                          onPressed: () async {
                                            final confirmDelete =
                                                await showDialog<bool>(
                                                  context: context,
                                                  builder: (confirmContext) {
                                                    return PointerInterceptor(
                                                      child: AlertDialog(
                                                        backgroundColor:
                                                            const Color(
                                                              0xFF0F1117,
                                                            ),
                                                        title: const Text(
                                                          'Delete Note?',
                                                          style: TextStyle(
                                                            color: Colors
                                                                .redAccent,
                                                          ),
                                                        ),
                                                        content: Text(
                                                          'Remove this note from page $notePage?',
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white70,
                                                              ),
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  confirmContext,
                                                                  false,
                                                                ),
                                                            child: const Text(
                                                              'Cancel',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white70,
                                                              ),
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  confirmContext,
                                                                  true,
                                                                ),
                                                            child: const Text(
                                                              'Delete',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .redAccent,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                );

                                            if (confirmDelete != true) return;

                                            await readerNoteRepository.delete(
                                              noteId,
                                            );

                                            await logReaderAction(
                                              action: 'delete_reader_note',
                                              details: {
                                                'noteId': noteId,
                                                'pageNumber': notePage,
                                              },
                                            );

                                            if (!context.mounted) return;

                                            ScaffoldMessenger.of(
                                              context,
                                            ).hideCurrentSnackBar();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text('Note deleted'),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Colors.greenAccent),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(noteSearchController.dispose);
  }

  Future<void> loadNarrationPreferences() async {
    await narrationPreferencesController.load(
      context: narrationPreferencesContext,
    );
  }

  Future<void> saveNarrationPreferences({String? selectedVoiceId}) async {
    await narrationPreferencesController.saveCurrent(
      context: narrationPreferencesContext,
      selectedVoiceId: selectedVoiceId,
    );
  }

  void observeNarrationSession() {
    narrationSessionTracker.observe(
      isPlaying: readerTtsService.isPlaying,
      pageNumber: readerTtsService.pageNumber,
      progressPercent: readerTtsService.progressPercent,
    );
  }

  Future<void> saveNarrationSessionSummary({bool finished = false}) async {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    final summary = finished
        ? narrationSessionTracker.finish()
        : narrationSessionTracker.snapshot();

    if (userEmail == null || !summary.hasActivity) return;

    try {
      await narrationSessionRepository.save(
        userEmail: userEmail,
        readerSessionId: readerSessionId,
        documentKey: readerDocumentKey,
        pdfTitle: widget.title,
        storagePath: normalizedReaderStoragePath,
        summary: summary,
      );
    } catch (_) {
      // Narration analytics must never interrupt listening.
    }
  }

  Future<void> saveNarrationCheckpoint(int pageNumber) async {
    final playbackStatus = narrationPlaybackCoordinator.status;
    final isCloudNarration = narrationPlaybackCoordinator.isUsingCloud;
    final cachedTextLength = narrationPageTextCache[pageNumber]?.length;

    await narrationProgressController.saveCurrent(
      context: narrationProgressContext,
      pageNumber: pageNumber,
      activePageNumber: isCloudNarration
          ? pageNumber
          : readerTtsService.pageNumber,
      characterOffset: isCloudNarration
          ? playbackStatus.currentCharacterEnd
          : readerTtsService.currentCharacterOffset,
      textLength: isCloudNarration
          ? cachedTextLength ?? readerTtsService.lastText.length
          : readerTtsService.lastText.length,
      languageLocale: readerTtsService.language.locale,
      rate: readerTtsService.rate,
    );
  }

  int narrationStartCharacterFor({
    required String text,
    required int targetPageNumber,
    ReaderNarrationCheckpoint? savedCheckpoint,
  }) {
    final playbackStatus = narrationPlaybackCoordinator.status;
    final hasCloudResume =
        narrationPlaybackCoordinator.isUsingCloud &&
        playbackStatus.progressPercent > 0 &&
        playbackStatus.progressPercent < 100;

    return narrationProgressController.startCharacterFor(
      text: text,
      targetPageNumber: targetPageNumber,
      livePageNumber: hasCloudResume
          ? targetPageNumber
          : readerTtsService.pageNumber,
      liveText: hasCloudResume ? text : readerTtsService.lastText,
      liveCharacterOffset: hasCloudResume
          ? playbackStatus.currentCharacterEnd
          : readerTtsService.currentCharacterOffset,
      hasLiveResume: hasCloudResume || readerTtsService.hasResumableProgress,
      savedCheckpoint: savedCheckpoint,
    );
  }

  Future<bool> moveNarrationAcrossPage({
    required int fromPage,
    required ReaderNarrationDirection direction,
    String source = 'narration_page_navigation',
    bool Function()? canStart,
  }) async {
    final pageCount = await loadPdfPageCount();
    var page = fromPage;

    while (true) {
      if (canStart != null && !canStart()) return false;

      page += direction == ReaderNarrationDirection.forward ? 1 : -1;

      if (page < 1 || page > pageCount) return false;

      final text = await loadNarrationTextForPage(page);
      if (canStart != null && !canStart()) return false;
      if (text.trim().isEmpty) continue;

      final startCharacter = direction == ReaderNarrationDirection.backward
          ? ReaderNarrationNavigator()
                .target(
                  text: text,
                  currentOffset: text.length,
                  direction: ReaderNarrationDirection.backward,
                )
                .offset
          : 0;

      if (canStart != null && !canStart()) return false;

      openPdfPage(page, source: source);
      return narrationPlaybackCoordinator.start(
        text: text,
        pageNumber: page,
        rate: readerTtsService.rate,
        startCharacter: startCharacter,
      );
    }
  }

  Future<void> continueNarrationAfterPage(int completedPage) async {
    await saveNarrationCheckpoint(completedPage);
    await saveNarrationSessionSummary();

    if (!readerTtsService.canContinueAfterPage(completedPage)) return;

    try {
      final continued = await moveNarrationAcrossPage(
        fromPage: completedPage,
        direction: ReaderNarrationDirection.forward,
        source: 'continuous_narration',
        canStart: () => readerTtsService.canContinueAfterPage(completedPage),
      );

      if (!continued) {
        readerTtsService.endContinuousPlayback();
        await logReaderAction(
          action: 'complete_document_narration',
          details: {'pageNumber': completedPage},
        );
        return;
      }

      await logReaderAction(
        action: 'continue_document_narration',
        details: {
          'fromPage': completedPage,
          'toPage': readerTtsService.pageNumber,
        },
      );
    } catch (error) {
      await logReaderAction(
        action: 'continue_document_narration_failed',
        details: {'pageNumber': completedPage, 'error': error.toString()},
      );
    }
  }

  Future<void> showSelectedTextNarrationDialog() async {
    if (!canUseViewerTools('selected_text_narration')) return;

    final selectionPage = currentPdfPage;
    final selectedText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return ReaderTextSelectionDialog(
          pageNumber: selectionPage,
          pageText: loadNarrationTextForPage(selectionPage),
        );
      },
    );

    if (selectedText == null || selectedText.trim().isEmpty || !mounted) return;

    await logReaderAction(
      action: 'select_text_narration',
      details: {
        'pageNumber': selectionPage,
        'characterCount': selectedText.length,
      },
    );

    final activeNarrationPage = readerTtsService.pageNumber;
    if (activeNarrationPage != null && readerTtsService.hasResumableProgress) {
      await saveNarrationCheckpoint(activeNarrationPage);
    }
    await narrationPlaybackCoordinator.stop();
    await saveNarrationSessionSummary();

    await showReaderNarrationDialog(selectedText: selectedText);
  }

  Future<void> showReaderNarrationDialog({String? selectedText}) async {
    if (!canUseViewerTools('page_narration')) return;

    await narrationPreferencesReady;
    if (!mounted) return;

    if (!narrationAccessPolicy.canChooseVoice) {
      await readerTtsService.useAssignedVoice();
    }

    narrationCloudSession.updateAccessPolicy(narrationAccessPolicy);
    unawaited(narrationCloudSession.refreshCatalog().catchError((_) => false));

    final narrationPage = currentPdfPage;
    final isSelectedPassage = selectedText != null;
    final allowContinuousNarration = !isSelectedPassage;
    var selectedPassageTracked = false;
    void prepareNarrationMode() {
      if (isSelectedPassage) {
        if (!selectedPassageTracked) {
          narrationSessionTracker.beginSelectedPassage();
          selectedPassageTracked = true;
        }
        return;
      }

      narrationSessionTracker.beginDocumentNarration();
    }

    int activeNarrationPage() {
      return narrationPlaybackCoordinator.isUsingCloud
          ? narrationPage
          : readerTtsService.pageNumber ?? narrationPage;
    }

    final narrationText = isSelectedPassage
        ? Future<String>.value(selectedText.trim())
        : loadNarrationTextForPage(narrationPage);
    var savedCheckpoint = isSelectedPassage
        ? null
        : await loadNarrationCheckpoint(narrationPage);

    void rememberLiveNarrationCheckpoint(int activePage) {
      final playbackStatus = narrationPlaybackCoordinator.status;
      final isCloudNarration = narrationPlaybackCoordinator.isUsingCloud;
      final textLength = isCloudNarration
          ? narrationPageTextCache[activePage]?.length ??
                readerTtsService.lastText.length
          : readerTtsService.lastText.length;
      final characterOffset = isCloudNarration
          ? playbackStatus.currentCharacterEnd
          : readerTtsService.currentCharacterOffset;

      if (textLength <= 0 ||
          characterOffset <= 0 ||
          characterOffset >= textLength) {
        return;
      }

      savedCheckpoint = ReaderNarrationCheckpoint(
        pageNumber: activePage,
        characterOffset: characterOffset,
        textLength: textLength,
        languageLocale: readerTtsService.language.locale,
        rate: readerTtsService.rate,
      );
    }

    await logReaderAction(
      action: 'open_page_narration',
      details: {'pageNumber': narrationPage},
    );

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return ReaderNarrationDialog(
          service: readerTtsService,
          playbackCoordinator: narrationPlaybackCoordinator,
          pageNumber: narrationPage,
          narrationText: narrationText,
          savedCheckpoint: savedCheckpoint,
          accessPolicy: narrationAccessPolicy,
          voiceCatalog: narrationVoiceCatalogView,
          sessionTracker: narrationSessionTracker,
          title: isSelectedPassage
              ? 'Selected Passage Narration'
              : 'Document Narration',
          onLanguageChanged: (language) async {
            await narrationPreferencesController.changeLanguage(
              context: narrationPreferencesContext,
              language: language,
            );
            final activePage = activeNarrationPage();
            await logReaderAction(
              action: 'change_narration_language',
              details: {'language': language.locale, 'pageNumber': activePage},
            );
          },
          onVoiceChanged: (ReaderNarrationVoice voice) async {
            if (!narrationAccessPolicy.canChooseVoice) {
              canUsePremiumNarration('change_narration_voice');
              return;
            }

            final selected = await narrationPreferencesController.changeVoice(
              context: narrationPreferencesContext,
              voice: voice,
            );
            if (!selected) return;

            final activePage = activeNarrationPage();
            await logReaderAction(
              action: 'change_narration_voice',
              details: {
                'voiceId': voice.id,
                'voiceName': voice.name,
                'voiceLocale': voice.locale,
                'voiceProvider': voice.provider.name,
                'pageNumber': activePage,
              },
            );
          },
          onRateChangeEnd: (rate) async {
            await narrationPreferencesController.changeRate(
              context: narrationPreferencesContext,
              rate: rate,
            );
            final activePage = activeNarrationPage();
            await logReaderAction(
              action: 'change_narration_speed',
              details: {'rate': rate, 'pageNumber': activePage},
            );
          },
          onPlay: (text) async {
            prepareNarrationMode();
            final activePage = activeNarrationPage();
            final startCharacter = narrationStartCharacterFor(
              text: text,
              targetPageNumber: activePage,
              savedCheckpoint: activePage == narrationPage
                  ? savedCheckpoint
                  : null,
            );
            final started = await narrationPlaybackCoordinator.start(
              text: text,
              pageNumber: activePage,
              rate: readerTtsService.rate,
              startCharacter: startCharacter,
              continueAcrossPages: allowContinuousNarration,
              selectedVoice: narrationPlaybackCoordinator.selectedVoice,
            );

            if (started) {
              await logReaderAction(
                action: 'start_page_narration',
                details: {
                  'pageNumber': activePage,
                  'language': readerTtsService.language.locale,
                  'rate': readerTtsService.rate,
                },
              );
            }
          },
          onPause: () async {
            await narrationPlaybackCoordinator.pause();
            final activePage = activeNarrationPage();
            rememberLiveNarrationCheckpoint(activePage);
            if (!isSelectedPassage) {
              await saveNarrationCheckpoint(activePage);
            }
            await saveNarrationSessionSummary();
            await logReaderAction(
              action: 'pause_page_narration',
              details: {'pageNumber': activePage},
            );
          },
          onResume: () async {
            final resumed = await narrationPlaybackCoordinator.resume();
            final activePage = activeNarrationPage();

            if (resumed) {
              await logReaderAction(
                action: 'resume_page_narration',
                details: {
                  'pageNumber': activePage,
                  'progressPercent': readerTtsService.progressPercent,
                },
              );
            }
          },
          onJumpBackward: (text) async {
            prepareNarrationMode();
            final activePage = activeNarrationPage();
            final currentOffset = narrationStartCharacterFor(
              text: text,
              targetPageNumber: activePage,
              savedCheckpoint: activePage == narrationPage
                  ? savedCheckpoint
                  : null,
            );
            final jump = narrationNavigator.target(
              text: text,
              currentOffset: currentOffset,
              direction: ReaderNarrationDirection.backward,
            );

            if (!isSelectedPassage &&
                jump.kind == ReaderNarrationJumpKind.pageEdge &&
                jump.offset == 0 &&
                activePage > 1) {
              await saveNarrationCheckpoint(activePage);
              final moved = await moveNarrationAcrossPage(
                fromPage: activePage,
                direction: ReaderNarrationDirection.backward,
              );

              if (moved) {
                await logReaderAction(
                  action: 'jump_previous_page_narration',
                  details: {
                    'fromPage': activePage,
                    'toPage': readerTtsService.pageNumber,
                  },
                );
              }
              return;
            }

            final started = await narrationPlaybackCoordinator.start(
              text: text,
              pageNumber: activePage,
              rate: readerTtsService.rate,
              startCharacter: jump.offset,
              continueAcrossPages: allowContinuousNarration,
            );

            if (started) {
              await logReaderAction(
                action: 'jump_backward_page_narration',
                details: {
                  'pageNumber': activePage,
                  'jumpKind': jump.kind.name,
                  'repeatCount': jump.repeatCount,
                  'progressPercent': readerTtsService.progressPercent,
                },
              );
            }
          },
          onJumpForward: (text) async {
            prepareNarrationMode();
            final activePage = readerTtsService.pageNumber ?? narrationPage;
            final currentOffset = narrationStartCharacterFor(
              text: text,
              targetPageNumber: activePage,
              savedCheckpoint: activePage == narrationPage
                  ? savedCheckpoint
                  : null,
            );
            final jump = narrationNavigator.target(
              text: text,
              currentOffset: currentOffset,
              direction: ReaderNarrationDirection.forward,
            );

            if (!isSelectedPassage && jump.offset >= text.length - 1) {
              await saveNarrationCheckpoint(activePage);
              final moved = await moveNarrationAcrossPage(
                fromPage: activePage,
                direction: ReaderNarrationDirection.forward,
              );

              if (moved) {
                await logReaderAction(
                  action: 'jump_next_page_narration',
                  details: {
                    'fromPage': activePage,
                    'toPage': readerTtsService.pageNumber,
                    'repeatCount': jump.repeatCount,
                  },
                );
              }
              return;
            }

            final started = await narrationPlaybackCoordinator.start(
              text: text,
              pageNumber: activePage,
              rate: readerTtsService.rate,
              startCharacter: jump.offset,
              continueAcrossPages: allowContinuousNarration,
            );

            if (started) {
              await logReaderAction(
                action: 'jump_forward_page_narration',
                details: {
                  'pageNumber': activePage,
                  'jumpKind': jump.kind.name,
                  'repeatCount': jump.repeatCount,
                  'progressPercent': readerTtsService.progressPercent,
                },
              );
            }
          },
          onStop: () async {
            final activePage = activeNarrationPage();
            rememberLiveNarrationCheckpoint(activePage);
            if (!isSelectedPassage) {
              await saveNarrationCheckpoint(activePage);
            }
            await narrationPlaybackCoordinator.stop();
            await saveNarrationSessionSummary();
            await logReaderAction(
              action: 'stop_page_narration',
              details: {'pageNumber': activePage},
            );
          },
        );
      },
    );

    if (!isSelectedPassage) {
      await saveNarrationCheckpoint(
        readerTtsService.pageNumber ?? narrationPage,
      );
    }
    await saveNarrationSessionSummary();
  }

  @override
  void initState() {
    super.initState();
    readerTtsService = ReaderTtsService(
      onPageCompleted: continueNarrationAfterPage,
    );
    narrationProgressRepository = ReaderNarrationProgressRepository();
    narrationProgressController = ReaderNarrationProgressController(
      store: narrationProgressRepository,
    );
    narrationPreferencesRepository = ReaderNarrationPreferencesRepository();
    narrationSessionRepository = ReaderNarrationSessionRepository();
    narrationSessionTracker = ReaderNarrationSessionTracker();
    readerBookmarkRepository = ReaderBookmarkRepository();
    readerHighlightRepository = ReaderHighlightRepository();
    readerNoteRepository = ReaderNoteRepository();
    savedPositionRepository = ReaderSavedPositionRepository();
    readerActivityRepository = ReaderActivityRepository();
    readerDeviceIdentity = ReaderDeviceIdentityResolver(
      storage: const HtmlDeviceIdentityStorage(),
      platformProvider: () => html.window.navigator.platform ?? '',
      deviceIdFactory: createReaderDeviceId,
    ).resolve();
    readerDeviceAuthorizationRepository = UserDeviceAuthorizationRepository();
    userAccessRepository = UserAccessRepository();
    final cloudNarrationRegistry = ReaderCloudNarrationRegistry(
      providers: [
        ReaderCloudNarrationCallableProvider(
          client: ReaderCloudNarrationHttpCallableClient.firebase(
            options: DefaultFirebaseOptions.currentPlatform,
            requiresAppCheckToken: false,
          ),
        ),
      ],
    );
    final cloudNarrationQueue = ReaderCloudNarrationPreparationQueue(
      registry: cloudNarrationRegistry,
    );
    final cloudNarrationPlaybackController =
        ReaderCloudNarrationPlaybackController(
          queue: cloudNarrationQueue,
          audioPlayer: createReaderCloudNarrationAudioPlayer(),
        );
    narrationCloudSession = ReaderCloudNarrationSessionCoordinator(
      registry: cloudNarrationRegistry,
      playbackController: cloudNarrationPlaybackController,
      accessPolicy: narrationAccessPolicy,
    );
    narrationPlaybackCoordinator = ReaderNarrationPlaybackCoordinator(
      ttsService: readerTtsService,
      cloudSession: narrationCloudSession,
      accessPolicyProvider: () => narrationAccessPolicy,
    );
    narrationPreferencesController = ReaderNarrationPreferencesController(
      store: narrationPreferencesRepository,
      ttsService: readerTtsService,
      playbackCoordinator: narrationPlaybackCoordinator,
    );
    narrationVoicePresenter = const ReaderNarrationVoiceCatalogPresenter();
    narrationNavigator = ReaderNarrationNavigator();
    readerTtsService.addListener(observeNarrationSession);
    narrationPreferencesReady = loadNarrationPreferences();
    readerSessionId =
        'reader-${widget.pdfUrl.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
    viewId =
        'pdf-viewer-${widget.pdfUrl.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
    currentPdfPage = widget.initialPage < 1 ? 1 : widget.initialPage;
    currentSearchQuery = widget.initialSearchQuery;
    startReaderProtectionObservers();
    checkViewerAccess();
  }

  @override
  void dispose() {
    saveNarrationSessionSummary(finished: true);
    readerVisibilitySubscription?.cancel();
    readerWindowBlurSubscription?.cancel();
    readerWindowFocusSubscription?.cancel();
    readerContextMenuSubscription?.cancel();
    readerPdfContextMenuSubscription?.cancel();
    readerPdfMouseDownSubscription?.cancel();
    protectedPdfScrollSubscription?.cancel();
    protectedPdfContextMenuSubscription?.cancel();
    protectedPdfMouseDownSubscription?.cancel();
    readerKeyDownSubscription?.cancel();
    protectedPdfRenderGeneration++;
    readerTtsService.removeListener(observeNarrationSession);
    narrationCloudSession.dispose();

    if (readerSessionStarted) {
      final startedAt = readerSessionStartedAt;
      final durationSeconds = startedAt == null
          ? 0
          : DateTime.now().difference(startedAt).inSeconds;

      logReaderSessionLifecycle(
        'ended',
        details: {'durationSeconds': durationSeconds},
      );
    }

    searchController.dispose();
    readerTtsService.dispose();
    super.dispose();
  }

  Future<void> showCompactReaderToolsMenu() async {
    if (!mounted) return;

    final selectedAction = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final menuHeight = (MediaQuery.sizeOf(dialogContext).height * 0.72)
            .clamp(320.0, 520.0)
            .toDouble();

        Widget item({
          required String value,
          required IconData icon,
          required String title,
          String? subtitle,
        }) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  hoverColor: Colors.greenAccent.withValues(alpha: 0.08),
                  splashColor: Colors.greenAccent.withValues(alpha: 0.12),
                  onTap: () => Navigator.of(dialogContext).pop(value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(icon, color: Colors.greenAccent, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.white38,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return PointerInterceptor(
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F1117),
            title: const Text(
              'Reader tools',
              style: TextStyle(color: Colors.greenAccent),
            ),
            content: SizedBox(
              width: 360,
              height: menuHeight,
              child: ListView(
                children: [
                  item(
                    value: 'selected_narration',
                    icon: Icons.ads_click,
                    title: 'Select passage',
                    subtitle: 'Choose page text for narration',
                  ),
                  item(
                    value: 'workspace',
                    icon: Icons.dashboard_customize_outlined,
                    title: 'Reader workspace',
                  ),
                  const Divider(color: Colors.white12),
                  item(
                    value: 'go_page',
                    icon: Icons.input,
                    title: 'Go to page',
                  ),
                  item(
                    value: 'save_position',
                    icon: Icons.bookmark_add,
                    title: 'Save reading position',
                  ),
                  item(
                    value: 'saved_positions',
                    icon: Icons.history,
                    title: 'Saved reading positions',
                  ),
                  const Divider(color: Colors.white12),
                  item(
                    value: 'add_bookmark',
                    icon: Icons.bookmark_add_outlined,
                    title: 'Bookmark current page',
                  ),
                  item(
                    value: 'bookmarks',
                    icon: Icons.bookmarks_outlined,
                    title: 'Reader bookmarks',
                  ),
                  const Divider(color: Colors.white12),
                  item(
                    value: 'add_highlight',
                    icon: Icons.border_color,
                    title: 'Add reader highlight',
                  ),
                  item(
                    value: 'highlights',
                    icon: Icons.format_color_fill,
                    title: 'Reader highlights',
                  ),
                  const Divider(color: Colors.white12),
                  item(
                    value: 'add_note',
                    icon: Icons.note_add,
                    title: 'Add reader note',
                  ),
                  item(
                    value: 'notes',
                    icon: Icons.list_alt,
                    title: 'Reader notes',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );

    if (selectedAction == null || !mounted) return;
    await runCompactReaderToolAction(selectedAction);
  }

  Future<void> runCompactReaderToolAction(String value) async {
    switch (value) {
      case 'selected_narration':
        await showSelectedTextNarrationDialog();
        break;
      case 'workspace':
        await showReaderWorkspaceDialog();
        break;
      case 'go_page':
        await showManualPageJumpDialog();
        break;
      case 'save_position':
        await showSaveReadingPositionDialog();
        break;
      case 'saved_positions':
        await showSavedReadingPositionsDialog();
        break;
      case 'add_bookmark':
        await addReaderBookmark();
        break;
      case 'bookmarks':
        await showReaderBookmarksDialog();
        break;
      case 'add_highlight':
        await addReaderHighlight();
        break;
      case 'highlights':
        await showReaderHighlightsDialog();
        break;
      case 'add_note':
        await addReaderNote();
        break;
      case 'notes':
        await showReaderNotesDialog();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.greenAccent),
            ),
            Text(
              '$readerAccessLabel - $readerSourceLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.greenAccent),
        actions: [
          IconButton(
            tooltip: 'Narrate document from tracked page',
            icon: const Icon(
              Icons.record_voice_over,
              size: 20,
              color: Colors.greenAccent,
            ),
            onPressed: showReaderNarrationDialog,
          ),
          IconButton(
            tooltip: shouldShowReaderPrivacyShield
                ? 'Return to read mode'
                : showReaderStatusOverlay
                ? 'Hide reader status'
                : 'Show reader status',
            icon: Icon(
              shouldShowReaderPrivacyShield || !showReaderStatusOverlay
                  ? Icons.visibility
                  : Icons.visibility_off,
              size: 20,
              color: Colors.greenAccent,
            ),
            onPressed: () {
              if (shouldShowReaderPrivacyShield) {
                restoreReaderPrivacyShield('reader_top_eye_restore');
                return;
              }

              final nextVisible = !showReaderStatusOverlay;

              setState(() {
                showReaderStatusOverlay = nextVisible;
              });

              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    nextVisible
                        ? 'Reader status shown.'
                        : 'Reader status hidden.',
                  ),
                ),
              );

              logReaderAction(
                action: 'toggle_reader_status_overlay',
                details: {
                  'visible': nextVisible,
                  'currentPdfPage': currentPdfPage,
                  'hasActiveSearch': currentSearchQuery.trim().isNotEmpty,
                },
              );
            },
          ),
          IconButton(
            tooltip: 'Search in PDF',
            icon: const Icon(Icons.search, size: 20, color: Colors.greenAccent),

            onPressed: () async {
              if (!canUseViewerTools('internal_pdf_search')) return;

              showDialog(
                context: this.context,
                builder: (dialogContext) {
                  void submitSearch() {
                    final keyword = searchController.text.trim();

                    Navigator.pop(dialogContext);

                    if (keyword.isEmpty) return;

                    showDialog(
                      context: this.context,
                      builder: (resultContext) {
                        return PointerInterceptor(
                          child: AlertDialog(
                            backgroundColor: const Color(0xFF0F1117),
                            title: Text(
                              'Results for "$keyword"',
                              style: const TextStyle(color: Colors.greenAccent),
                            ),
                            content: SizedBox(
                              width: 500,
                              height: 450,

                              child: Column(
                                children: [
                                  const SizedBox(height: 20),

                                  Expanded(
                                    child: FutureBuilder<List<Map<String, dynamic>>>(
                                      future: searchPdfText(keyword),

                                      builder: (context, snapshot) {
                                        if (snapshot.hasError) {
                                          return Center(
                                            child: Text(
                                              'Search failed: ${snapshot.error}',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          );
                                        }

                                        if (!snapshot.hasData) {
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        }

                                        final results = snapshot.data!;

                                        if (results.isEmpty) {
                                          return const Center(
                                            child: Text(
                                              'No matches in this PDF.',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          );
                                        }

                                        return ListView.builder(
                                          itemCount: results.length + 1,
                                          itemBuilder: (context, index) {
                                            if (index == 0) {
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: Text(
                                                  formatSearchResultSummary(
                                                    results,
                                                  ),
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              );
                                            }

                                            final data = results[index - 1];

                                            return Card(
                                              color: const Color(0xFF1A1D26),
                                              child: ListTile(
                                                onTap: () {
                                                  Navigator.pop(resultContext);

                                                  final page =
                                                      data['pageNumber'] is int
                                                      ? data['pageNumber']
                                                            as int
                                                      : int.tryParse(
                                                              data['pageNumber']
                                                                  .toString(),
                                                            ) ??
                                                            1;

                                                  openPdfPage(
                                                    page,
                                                    searchQuery: keyword,
                                                    source:
                                                        'internal_search_result',
                                                  );
                                                },

                                                title: Text(
                                                  'Open Page ${data['pageNumber']} - Match ${data['matchNumber'] ?? 1}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                subtitle: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Matching excerpt',
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                      ),
                                                    ),

                                                    const SizedBox(height: 6),

                                                    RichText(
                                                      maxLines: 3,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      text: TextSpan(
                                                        children:
                                                            highlightSearchText(
                                                              data['text']
                                                                  .toString(),
                                                              keyword,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(resultContext),
                                child: const Text(
                                  'Close',
                                  style: TextStyle(color: Colors.greenAccent),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }

                  return PointerInterceptor(
                    child: AlertDialog(
                      backgroundColor: const Color(0xFF0F1117),
                      title: const Text(
                        'Search This PDF',
                        style: TextStyle(color: Colors.greenAccent),
                      ),
                      content: TextField(
                        enabled: true,
                        readOnly: false,
                        autofocus: true,
                        controller: searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => submitSearch(),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Search term',
                          labelStyle: TextStyle(color: Colors.white70),
                          hintText: 'Keyword or phrase',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      actions: [
                        PointerInterceptor(
                          child: TextButton(
                            onPressed: () {
                              searchController.clear();
                            },
                            child: const Text(
                              'Clear',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                        PointerInterceptor(
                          child: TextButton(
                            onPressed: submitSearch,
                            child: const Text(
                              'Search',
                              style: TextStyle(color: Colors.greenAccent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          if (currentSearchQuery.trim().isNotEmpty)
            IconButton(
              tooltip: 'Clear active PDF search',
              icon: const Icon(
                Icons.search_off,
                size: 20,
                color: Colors.greenAccent,
              ),
              onPressed: clearActivePdfSearch,
            ),
          PointerInterceptor(
            child: IconButton(
              tooltip: 'More reader tools',
              onPressed: showCompactReaderToolsMenu,
              icon: const Icon(
                Icons.more_vert,
                size: 22,
                color: Colors.greenAccent,
              ),
            ),
          ),
        ],
      ),
      body: isCheckingViewerAccess
          ? const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            )
          : !canViewDocument
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Subscription required to open this PDF.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            )
          : Stack(
              children: [
                buildPdfDocumentSurface(),

                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.08,
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            readerWatermarkText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (shouldShowReaderPrivacyShield)
                  Positioned.fill(
                    child: PointerInterceptor(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              restoreReaderPrivacyShield('reader_shield_tap'),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.94),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Return to read mode',
                                      iconSize: 56,
                                      color: Colors.greenAccent,
                                      onPressed: () =>
                                          restoreReaderPrivacyShield(
                                            'reader_shield_eye_button',
                                          ),
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      readerProtectionPolicy
                                          .inactiveShieldTitle,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      readerProtectionPolicy
                                          .inactiveShieldMessage,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Click to continue reading',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showReaderStatusOverlay)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          border: Border.all(color: Colors.greenAccent),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          readerStatusText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
