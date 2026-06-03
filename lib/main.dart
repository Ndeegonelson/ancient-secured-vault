import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'firebase_options.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui_web' as ui;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
                border: Border.all(
                  color: Colors.greenAccent,
                ),
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
        title: const Text(
          'Login',
          style: TextStyle(color: Colors.greenAccent),
        ),
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
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
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

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                      ),
                    );
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

class UserAccessState {
  final bool isAdmin;
  final bool hasActiveSubscription;
  final String accessLevel;

  const UserAccessState({
    this.isAdmin = false,
    this.hasActiveSubscription = false,
    this.accessLevel = 'free',
  });

  factory UserAccessState.fromFirestore(Map<String, dynamic>? data) {
    return UserAccessState(
      isAdmin: data?['role'] == 'admin',
      hasActiveSubscription: data?['subscriptionStatus'] == 'active',
      accessLevel: data?['accessLevel']?.toString() ?? 'free',
    );
  }

  bool get canAccessMainVault => isAdmin || hasActiveSubscription;

  bool get canManageVault => isAdmin;

  bool canOpenPdfWithAccessLevel(String documentAccessLevel) {
    final normalizedAccessLevel = documentAccessLevel.trim().toLowerCase();

    if (normalizedAccessLevel == 'premium') {
      return canAccessMainVault;
    }

    return true;
  }
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> freePdfFiles = [];
  List<Map<String, dynamic>> premiumPdfFiles = [];

  bool isLoading = false;
  UserAccessState userAccess = const UserAccessState();
  String? pdfLoadError;
  String searchMode = 'all';
  String accessFilter = 'all';
  List<Map<String, dynamic>> userNotes = [];

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    await checkUserRole();
    await loadPDFs();
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

  Future<void> saveUserNote({
    required String pdfTitle,
    required String selectedText,
    required String note,
    required String color,
    required int pageNumber,
  }) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await FirebaseFirestore.instance.collection('reader_notes').add({
    'userEmail': user.email,
    'pdfTitle': pdfTitle,
    'selectedText': selectedText,
    'note': note,
    'color': color,
    'pageNumber': pageNumber,
    'createdAt': FieldValue.serverTimestamp(),
  });
}
  Future<void> checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.email)
        .get();

    if (doc.exists) {
      final data = doc.data();

      setState(() {
        userAccess = UserAccessState.fromFirestore(data);
      });
    }
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

  Future<void> uploadPDF() async {
  if (!requireVaultManagerAccess()) return;

  try {
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

        final storagePath = 'vault_pdfs/$fileName';
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
            customMetadata: {
              'accessLevel': 'premium',
              'uploadedBy': FirebaseAuth.instance.currentUser?.email ?? '',
              'originalFileName': fileName,
            },
          ),
        );

        await indexPdfForSearch(
          pdfBytes: fileBytes,
          pdfTitle: fileName,
          accessLevel: 'premium',
          storagePath: storagePath,
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  }
}

Future<void> indexPdfForSearch({
  required Uint8List pdfBytes,
  required String pdfTitle,
  required String accessLevel,
  required String storagePath,
  String? pdfUrl,
}) async {
  final document = PdfDocument(inputBytes: pdfBytes);
  final extractor = PdfTextExtractor(document);
  final normalizedAccessLevel = accessLevel.trim().toLowerCase();



  for (int i = 0; i < document.pages.count; i++) {
    final text = extractor.extractText(
      startPageIndex: i,
      endPageIndex: i,
    );

    if (text.trim().isEmpty) continue;

    final lowerText = text.toLowerCase();

    final keywords = lowerText
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), ' ')
        .split(' ')
        .where((word) => word.trim().length > 2)
        .toSet()
        .take(300)
        .toList();

    final searchIndexData = <String, dynamic>{
      'pdfTitle': pdfTitle,
      'storagePath': storagePath,
      'pageNumber': i + 1,
      'text': text.length > 1200 ? text.substring(0, 1200) : text,
      'textLower': lowerText,
      'keywords': keywords,
      'accessLevel': normalizedAccessLevel,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (normalizedAccessLevel != 'premium' && pdfUrl != null) {
      searchIndexData['pdfUrl'] = pdfUrl;
    }

    await FirebaseFirestore.instance
        .collection('pdf_search_index')
        .add(searchIndexData);
  }

  document.dispose();
}

Future<void> indexExistingVaultPdfs() async {
  if (!requireVaultManagerAccess()) return;

  try {
    Future<void> indexFolder(String folderName, String level) async {
      final result = await FirebaseStorage.instance.ref(folderName).listAll();

      for (final item in result.items) {
        final existing = await FirebaseFirestore.instance
            .collection('pdf_search_index')
            .where('pdfTitle', isEqualTo: item.name)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          continue;
        }

        final url = await item.getDownloadURL();
        final response = await http
    .get(Uri.parse(url))
    .timeout(const Duration(seconds: 25));

        await indexPdfForSearch(
          pdfBytes: response.bodyBytes,
          pdfUrl: url,
          pdfTitle: item.name,
          accessLevel: level,
          storagePath: item.fullPath,
        );
      }
    }

    await indexFolder('free_pdfs', 'free');
    await indexFolder('vault_pdfs', 'premium');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All vault PDFs indexed successfully'),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Indexing failed: $e')),
    );
  }
}

  Future<void> loadPDFs() async {
    setState(() {
      isLoading = true;
      pdfLoadError = null;
    });

    try {
      final freeResult =
          await FirebaseStorage.instance.ref('free_pdfs').listAll();

      final loadedFreeFiles = <Map<String, dynamic>>[];
      final loadedPremiumFiles = <Map<String, dynamic>>[];

      for (var item in freeResult.items) {
        loadedFreeFiles.add({
          'name': item.name,
          'storagePath': item.fullPath,
        });
      }

      if (userAccess.canAccessMainVault) {
        final premiumResult =
            await FirebaseStorage.instance.ref('vault_pdfs').listAll();

        for (var item in premiumResult.items) {
          loadedPremiumFiles.add({
            'name': item.name,
            'storagePath': item.fullPath,
          });
        }
      }

      loadedFreeFiles.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );
      loadedPremiumFiles.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );

      if (!mounted) return;

      setState(() {
        freePdfFiles = loadedFreeFiles;
        premiumPdfFiles = loadedPremiumFiles;
        pdfLoadError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        pdfLoadError = 'Could not load vault PDFs. Please try again.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
      return await FirebaseStorage.instance
          .ref(storagePath)
          .getDownloadURL();
    } catch (e) {
      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open this PDF: $e')),
      );
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
List<TextSpan> highlightSearchText(
  String text,
  String keyword,
) {
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

Future<void> showGlobalSearchResults(String keyword) async {
  String accessFilter = 'all';

  showDialog(
    context: context,
    builder: (resultContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          
          return AlertDialog(
            backgroundColor: const Color(0xFF0F1117),

            title: Text(
              'Vault Results for "$keyword"',
              style: const TextStyle(
                color: Colors.greenAccent,
              ),
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
                          });
                        },
                      ),

                      ChoiceChip(
                        label: const Text('Free'),
                        selected: accessFilter == 'free',
                        onSelected: (_) {
                          setState(() {
                            accessFilter = 'free';
                          });
                        },
                      ),

                      ChoiceChip(
                        label: const Text('Premium'),
                        selected: accessFilter == 'premium',
                        onSelected: (_) {
                          setState(() {
                            accessFilter = 'premium';
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  Expanded(
                    child: FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('pdf_search_index')
                          .where(
                            'keywords',
                            arrayContains: keyword.toLowerCase(),
                          )
                          .limit(30)
                          .get(),

                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = snapshot.data!.docs;

                        List<QueryDocumentSnapshot> filteredDocs =
                            docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final documentAccessLevel =
                              data['accessLevel']?.toString() ?? 'free';

                          return userAccess.canOpenPdfWithAccessLevel(
                            documentAccessLevel,
                          );
                        }).toList();

                        if (accessFilter == 'free') {
                          filteredDocs = filteredDocs.where((doc) {
                            final data =
                                doc.data() as Map<String, dynamic>;

                            return (data['accessLevel'] ?? 'free') ==
                                'free';
                          }).toList();
                        }

                        if (accessFilter == 'premium') {
                          filteredDocs = filteredDocs.where((doc) {
                            final data =
                                doc.data() as Map<String, dynamic>;

                            return (data['accessLevel'] ?? 'free') ==
                                'premium';
                          }).toList();
                        }

                        if (filteredDocs.isEmpty) {
                          return const Center(
                            child: Text(
                              'No matching vault documents found.',
                              style: TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: filteredDocs.length,

                          itemBuilder: (context, index) {
                            final data = filteredDocs[index].data()
                                as Map<String, dynamic>;

                            return Card(
                              color: const Color(0xFF1A1D26),

                              child: ListTile(
                                leading: Icon(
                                  Icons.picture_as_pdf,
                                  color:
                                      (data['accessLevel'] ?? 'free') ==
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
                                      'Page ${data['pageNumber']}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),

                                    const SizedBox(height: 6),

                                    Text(
                                      data['text']
                                          .toString()
                                          .substring(
                                            0,
                                            data['text']
                                                        .toString()
                                                        .length >
                                                    150
                                                ? 150
                                                : data['text']
                                                    .toString()
                                                    .length,
                                          ),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),

                                onTap: () async {
                                  final resultAccessLevel =
                                      data['accessLevel']?.toString() ??
                                          'free';

                                  if (!userAccess.canOpenPdfWithAccessLevel(
                                    resultAccessLevel,
                                  )) {
                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Subscription required to open this PDF.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final pdfUrl =
                                      await resolveSearchResultPdfUrl(data);

                                  if (pdfUrl == null) return;
                                  if (!mounted || !resultContext.mounted) {
                                    return;
                                  }

                                  final pageNumber =
                                      data['pageNumber'] is int
                                          ? data['pageNumber'] as int
                                          : int.tryParse(
                                                data['pageNumber'].toString(),
                                              ) ??
                                              0;

                                  Navigator.pop(resultContext);

                                  Navigator.push(
                                    this.context,
                                    MaterialPageRoute(
                                      builder: (context) => PDFViewerScreen(
                                        pdfUrl: pdfUrl,
                                        title: data['pdfTitle'].toString(),
                                        initialPage: pageNumber,
                                        initialSearchQuery: keyword,
                                        accessLevel: resultAccessLevel,
                                        openSource: 'global_search_result',
                                        storagePath:
                                            data['storagePath']?.toString() ??
                                                '',
                                      ),
                                    ),
                                  );
                                },
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
              PointerInterceptor(
  child: TextButton(
    onPressed: () =>
        Navigator.pop(resultContext),

    child: const Text(
      'Close',
      style: TextStyle(
        color: Colors.greenAccent,
      ),
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

  @override
  Widget build(BuildContext context) {
    final bool canAccessMainVault = userAccess.canAccessMainVault;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Ancient Secure Vault',
          style: TextStyle(color: Colors.greenAccent),
        ),

        actions: [
          if (userAccess.isAdmin)
            IconButton(
              icon: const Icon(Icons.upload_file, color: Colors.greenAccent),
              onPressed: uploadPDF,
            ),

if (userAccess.isAdmin)
  IconButton(
    tooltip: 'Index Vault PDFs',
    icon: const Icon(Icons.manage_search, color: Colors.greenAccent),
    onPressed: () async {
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

      if (!context.mounted) return;

      Navigator.pop(context);
    },
  ),

            IconButton(
  icon: const Icon(
    Icons.search,
    color: Colors.greenAccent,
  ),

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
        const Icon(Icons.error_outline, color: Colors.redAccent),
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

const Text(
  'FREE ACCESS ZONE',
  style: TextStyle(
    color: Colors.orangeAccent,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 15),

if (freePdfFiles.isEmpty)
  const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Text(
      'No free PDFs available yet.',
      style: TextStyle(color: Colors.white70),
    ),
  )
else
ListView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: freePdfFiles.length,
  itemBuilder: (context, index) {
    return Card(
      color: Colors.orange.withValues(alpha: 0.12),
      child: ListTile(
        leading: const Icon(
          Icons.picture_as_pdf,
          color: Colors.orangeAccent,
        ),
        title: Text(
          freePdfFiles[index]['name'],
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: const Text(
          'Free Access PDF',
          style: TextStyle(color: Colors.white70),
        ),
        onTap: () async {
          final pdfUrl = await resolveSearchResultPdfUrl(
            freePdfFiles[index],
          );

          if (pdfUrl == null) return;

          if (!context.mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PDFViewerScreen(
                pdfUrl: pdfUrl,
                title: freePdfFiles[index]['name'],
                accessLevel: 'free',
                openSource: 'free_dashboard',
                storagePath:
                    freePdfFiles[index]['storagePath']?.toString() ?? '',
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
            const Text(
              'MAIN VAULT PDFs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            if (premiumPdfFiles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No protected PDFs available yet.',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: premiumPdfFiles.length,
              itemBuilder: (context, index) {

                return Card(
                  color: Colors.green.withValues(alpha: 0.12),

                  child: ListTile(
                    leading: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.greenAccent,
                    ),

                    title: Text(
                      premiumPdfFiles[index]['name'],
                      style: const TextStyle(color: Colors.white),
                    ),

                    subtitle: const Text(
                      'Protected PDF',
                      style: TextStyle(color: Colors.white70),
                    ),

                    onTap: () async {
                      final pdfUrl = await resolveSearchResultPdfUrl(
                        premiumPdfFiles[index],
                      );

                      if (pdfUrl == null) return;

                      if (!context.mounted) return;

                      Navigator.push(
                        context,

                        MaterialPageRoute(
                          builder: (context) => PDFViewerScreen(
                            pdfUrl: pdfUrl,
                            title: premiumPdfFiles[index]['name'],
                            accessLevel: 'premium',
                            openSource: 'premium_dashboard',
                            storagePath: premiumPdfFiles[index]['storagePath']
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
class PDFViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;
  final int initialPage;
  final String initialSearchQuery;
  final String accessLevel;
  final String openSource;
  final String storagePath;

  const PDFViewerScreen({
  super.key,
  required this.pdfUrl,
  required this.title,
  this.initialPage = 0,
  this.initialSearchQuery = '',
  this.accessLevel = 'free',
  this.openSource = 'direct_open',
  this.storagePath = '',
});

  @override
State<PDFViewerScreen> createState() =>
    _PDFViewerScreenState();
}

class _PDFViewerScreenState
    extends State<PDFViewerScreen> {

  final TextEditingController searchController =
      TextEditingController();

      String accessFilter = 'all';

final PdfViewerController pdfViewerController = PdfViewerController();
final PdfTextSearchResult pdfSearchResult = PdfTextSearchResult();

      String searchQuery = '';
      Map<String, dynamic>? latestReadingPosition;
      late final String viewId;
      html.IFrameElement? pdfIframe;
      int currentPdfPage = 1;
      int? pdfPageCount;
      String currentSearchQuery = '';
      bool isCheckingViewerAccess = true;
      bool canViewDocument = false;
      bool readerSessionStarted = false;
      bool showReaderStatusOverlay = true;
      DateTime? readerSessionStartedAt;
      late final String readerSessionId;

String get shortReaderSessionId {
  if (readerSessionId.length <= 8) {
    return readerSessionId;
  }

  return readerSessionId.substring(readerSessionId.length - 8);
}

String get normalizedReaderStoragePath => widget.storagePath.trim();

String get readerSourceLabel => widget.openSource.replaceAll('_', ' ');

String get readerAccessLabel => widget.accessLevel.trim().toUpperCase();

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

String formatReaderNoteTime(Map<String, dynamic> note) {
  final updatedAt = note['updatedAt'];

  if (updatedAt is Timestamp) {
    return 'Updated: ${formatReaderTimestamp(updatedAt.toDate())}';
  }

  return 'Saved: ${formatSavedPositionTime(note['createdAt'])}';
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
  final searchStatus = searchText.isEmpty ? 'No active search' : 'Search: $searchText';

  return 'Page $currentPdfPage | $readerAccessLabel | $searchStatus';
}

String get readerWatermarkText {
  return 'Protected by Ancient Secure Docs\n'
      '${FirebaseAuth.instance.currentUser?.email ?? ''}\n'
      'Session: $shortReaderSessionId\n'
      'Access: $readerAccessLabel | Source: $readerSourceLabel\n'
      'Opened: ${formatReaderTimestamp(readerSessionStartedAt)}';
}

void addStoragePathToLog(Map<String, dynamic> logData) {
  final storagePath = normalizedReaderStoragePath;

  if (storagePath.isNotEmpty) {
    logData['storagePath'] = storagePath;
  }
}

Future<UserAccessState> loadCurrentUserAccess() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return const UserAccessState();
  }

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.email)
      .get();

  return UserAccessState.fromFirestore(doc.data());
}

Future<void> checkViewerAccess() async {
  final access = await loadCurrentUserAccess();
  final canOpen = access.canOpenPdfWithAccessLevel(widget.accessLevel);

  if (!mounted) return;

  await logReaderAccessAttempt(
    allowed: canOpen,
    userAccess: access,
  );

  if (!mounted) return;

  setState(() {
    canViewDocument = canOpen;
    isCheckingViewerAccess = false;
  });

  if (!canOpen) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Subscription required to open this PDF.'),
      ),
    );
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
  required bool allowed,
  required UserAccessState userAccess,
}) async {
  final user = FirebaseAuth.instance.currentUser;

  try {
    final logData = <String, dynamic>{
      'userEmail': user?.email,
      'pdfTitle': widget.title,
      'readerSessionId': readerSessionId,
      'documentAccessLevel': widget.accessLevel,
      'openSource': widget.openSource,
      'userAccessLevel': userAccess.accessLevel,
      'initialPage': widget.initialPage,
      'hasInitialSearchQuery': widget.initialSearchQuery.trim().isNotEmpty,
      'isAdmin': userAccess.isAdmin,
      'hasActiveSubscription': userAccess.hasActiveSubscription,
      'allowed': allowed,
      'createdAt': FieldValue.serverTimestamp(),
    };

    addStoragePathToLog(logData);

    await FirebaseFirestore.instance.collection('reader_access_logs').add(
          logData,
        );
  } catch (_) {
    // Logging should not block the reader if Firestore rules are not ready yet.
  }
}

Future<void> logReaderAction({
  required String action,
  Map<String, dynamic> details = const {},
}) async {
  final user = FirebaseAuth.instance.currentUser;

  try {
    final logData = <String, dynamic>{
      'userEmail': user?.email,
      'pdfTitle': widget.title,
      'readerSessionId': readerSessionId,
      'documentAccessLevel': widget.accessLevel,
      'openSource': widget.openSource,
      'action': action,
      'details': details,
      'createdAt': FieldValue.serverTimestamp(),
    };

    addStoragePathToLog(logData);

    await FirebaseFirestore.instance.collection('reader_activity_logs').add(
          logData,
        );
  } catch (_) {
    // Activity logging should not interrupt the reader experience.
  }
}

Future<void> logReaderSessionLifecycle(
  String event, {
  Map<String, dynamic> details = const {},
}) async {
  final user = FirebaseAuth.instance.currentUser;

  try {
    final logData = <String, dynamic>{
      'userEmail': user?.email,
      'pdfTitle': widget.title,
      'readerSessionId': readerSessionId,
      'documentAccessLevel': widget.accessLevel,
      'openSource': widget.openSource,
      'event': event,
      'details': details,
      'createdAt': FieldValue.serverTimestamp(),
    };

    addStoragePathToLog(logData);

    await FirebaseFirestore.instance.collection('reader_session_logs').add(
          logData,
        );
  } catch (_) {
    // Session logging should not interrupt the reader experience.
  }
}

bool canUseViewerTools(String attemptedAction) {
  if (canViewDocument) return true;

  logReaderAction(
    action: 'blocked_reader_tool_attempt',
    details: {
      'attemptedAction': attemptedAction,
    },
  );

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Subscription required to use this PDF.'),
    ),
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
  if (user == null) return;

  final snapshot = await FirebaseFirestore.instance
      .collection('reading_positions')
      .where('userEmail', isEqualTo: user.email)
      .where('pdfTitle', isEqualTo: widget.title)
      .get();

  if (snapshot.docs.isNotEmpty) {
    final position = sortReadingPositionsByNewest(snapshot.docs).first.data()
        as Map<String, dynamic>;
    final savedPage =
        int.tryParse(position['pageNumber'].toString()) ?? 1;

    latestReadingPosition = position;

    if (widget.initialPage == 0) {
      openPdfPage(
        savedPage,
        source: 'latest_saved_position',
      );
    }
  }
}

String buildPdfViewerUrl({
  required int pageNumber,
  String searchQuery = '',
}) {
  final safePageNumber = pageNumber < 1 ? 1 : pageNumber;
  final safeSearchQuery = searchQuery.trim();
  final searchFragment = safeSearchQuery.isEmpty
      ? ''
      : '&search=${Uri.encodeComponent(safeSearchQuery)}';

  return '${widget.pdfUrl}#toolbar=0&navpanes=0&scrollbar=1&page=$safePageNumber$searchFragment';
}

void registerPdfViewer() {
  ui.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) {
      final iframe = html.IFrameElement()
        ..src = buildPdfViewerUrl(
          pageNumber: currentPdfPage,
          searchQuery: currentSearchQuery,
        )
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';

      pdfIframe = iframe;
      return iframe;
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

  pdfIframe?.src = buildPdfViewerUrl(
    pageNumber: currentPdfPage,
    searchQuery: currentSearchQuery,
  );
}

Future<bool> goToPdfPage(int page) async {
  if (page < 1) {
    if (!mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter a valid page number.'),
      ),
    );
    return false;
  }

  late final int pageCount;

  try {
    pageCount = await loadPdfPageCount();
  } catch (e) {
    if (!mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
    return false;
  }

  if (page > pageCount) {
    if (!mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('This document has only $pageCount pages.'),
      ),
    );
    return false;
  }

  openPdfPage(page, source: 'manual_page_jump');

  if (!mounted) return false;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Opened page $page of $pageCount'),
    ),
  );

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

  if (user == null) {
    return false;
  }

  if (page < 1) {
    if (!mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter a valid page number.'),
      ),
    );
    return false;
  }

  late final int pageCount;

  try {
    pageCount = await loadPdfPageCount();
  } catch (e) {
    if (!mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
    return false;
  }

  if (page > pageCount) {
    if (!mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('This document has only $pageCount pages.'),
      ),
    );
    return false;
  }

  await FirebaseFirestore.instance.collection('reading_positions').add({
    'userEmail': user.email,
    'pdfTitle': widget.title,
    'pageNumber': page,
    'createdAt': FieldValue.serverTimestamp(),
  });

  await logReaderAction(
    action: 'save_reading_position',
    details: {
      'pageNumber': page,
      'pageCount': pageCount,
    },
  );

  if (!mounted) return false;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Reading position saved: Page $page'),
    ),
  );

  return true;
}

 List<TextSpan> highlightSearchText(
  String text,
  String keyword,
) {
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
      final text = extractor.extractText(
        startPageIndex: i,
        endPageIndex: i,
      );

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

@override
void initState() {
  super.initState();
  readerSessionId =
      'reader-${widget.pdfUrl.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
  viewId =
      'pdf-viewer-${widget.pdfUrl.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
  currentPdfPage = widget.initialPage < 1 ? 1 : widget.initialPage;
  currentSearchQuery = widget.initialSearchQuery;
  checkViewerAccess();
}

@override
void dispose() {
  if (readerSessionStarted) {
    final startedAt = readerSessionStartedAt;
    final durationSeconds = startedAt == null
        ? 0
        : DateTime.now().difference(startedAt).inSeconds;

    logReaderSessionLifecycle(
      'ended',
      details: {
        'durationSeconds': durationSeconds,
      },
    );
  }

  searchController.dispose();
  super.dispose();
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
          tooltip: showReaderStatusOverlay
              ? 'Hide reader status'
              : 'Show reader status',
          icon: Icon(
            showReaderStatusOverlay
                ? Icons.visibility_off
                : Icons.visibility,
            size: 20,
            color: Colors.greenAccent,
          ),
          onPressed: () {
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
  icon: const Icon(
    Icons.search,
    size: 20,
    color: Colors.greenAccent,
  ),

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
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final results = snapshot.data!;


            if (results.isEmpty) {
              return const Center(
                child: Text(
                  'No matches in this PDF.',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            return ListView.builder(
              itemCount: results.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      formatSearchResultSummary(results),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                }

                final data = results[index - 1];

                return Card(
                  color: const Color(0xFF1A1D26),
                 child: ListTile(
  onTap: () {
    Navigator.pop(resultContext);

    final page = data['pageNumber'] is int
        ? data['pageNumber'] as int
        : int.tryParse(data['pageNumber'].toString()) ?? 1;

    openPdfPage(
      page,
      searchQuery: keyword,
      source: 'internal_search_result',
    );
  },

  title: Text(
    'Open Page ${data['pageNumber']} - Match ${data['matchNumber'] ?? 1}',
    style: const TextStyle(color: Colors.white),
  ),
subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
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
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: highlightSearchText(
          data['text'].toString(),
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
IconButton(
  tooltip: 'Go to page',
  icon: const Icon(
    Icons.input,
    size: 20,
    color: Colors.greenAccent,
  ),
  onPressed: () async {
    if (!canUseViewerTools('manual_page_jump')) return;

    await logReaderAction(
      action: 'open_manual_page_jump_dialog',
      details: {
        'currentPdfPage': currentPdfPage,
      },
    );

    if (!mounted) return;

    final pageController = TextEditingController(
      text: currentPdfPage.toString(),
    );

    showDialog(
      context: this.context,
      builder: (dialogContext) {
        Future<void> submitPageJump() async {
          final page =
              int.tryParse(pageController.text.trim()) ?? 0;

          final opened = await goToPdfPage(page);

          if (!dialogContext.mounted) return;

          if (opened) {
            Navigator.pop(dialogContext);
          }
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
                  labelText: 'Page to open',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'Page number',
                  hintStyle: const TextStyle(color: Colors.white54),
                  helperText: pdfPageCount == null
                      ? 'Tracked page: $currentPdfPage'
                      : 'Tracked page: $currentPdfPage of $pdfPageCount',
                  suffixText: 'Enter opens',
                  helperStyle: const TextStyle(color: Colors.white54),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              PointerInterceptor(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
              PointerInterceptor(
                child: TextButton(
                  onPressed: submitPageJump,
                  child: const Text(
                    'Open',
                    style: TextStyle(color: Colors.greenAccent),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(pageController.dispose);
  },
),
          IconButton(
  tooltip: 'Save reading position',
  icon: const Icon(
    Icons.bookmark_add,
    size: 20,
    color: Colors.greenAccent,
  ),
  onPressed: () async {
    if (!canUseViewerTools('open_save_reading_position_dialog')) return;

    await logReaderAction(
      action: 'open_save_reading_position_dialog',
      details: {
        'currentPdfPage': currentPdfPage,
      },
    );

    if (!mounted) return;

    final pageController = TextEditingController(
      text: currentPdfPage.toString(),
    );

    showDialog(
      context: this.context,
      builder: (dialogContext) {
        Future<void> submitTypedSave() async {
          if (!canUseViewerTools('save_reading_position')) return;

          final page =
              int.tryParse(pageController.text.trim()) ?? 0;

          final saved =
              await saveReadingPositionPage(page);

          if (!dialogContext.mounted) return;

          if (saved) {
            Navigator.pop(dialogContext);
          }
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
                onSubmitted: (_) => submitTypedSave(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Page to save',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'Page number',
                  hintStyle: const TextStyle(color: Colors.white54),
                  helperText: 'Tracked page: $currentPdfPage',
                  suffixText: 'Enter saves',
                  helperStyle: const TextStyle(color: Colors.white54),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              PointerInterceptor(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
              PointerInterceptor(
                child: TextButton(
                  onPressed: () async {
                    if (!canUseViewerTools('save_reading_position')) return;

                    final saved =
                        await saveReadingPositionPage(currentPdfPage);

                    if (!dialogContext.mounted) return;

                    if (saved) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text(
                    'Save Tracked',
                    style:
                        TextStyle(color: Colors.greenAccent),
                  ),
                ),
              ),
              PointerInterceptor(
                child: TextButton(
                  onPressed: submitTypedSave,
                  child: const Text(
                    'Save Typed',
                    style:
                        TextStyle(color: Colors.greenAccent),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(pageController.dispose);
  },
),
IconButton(
  tooltip: 'Saved reading positions',
  icon: const Icon(Icons.history, size: 20, color: Colors.greenAccent),
 
  onPressed: () async {
    if (!canUseViewerTools('view_saved_reading_positions')) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await logReaderAction(
      action: 'view_saved_reading_positions',
    );

    if (!mounted) return;

    showDialog(
      context: this.context,
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
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reading_positions')
                      .where('userEmail', isEqualTo: user.email)
                      .where('pdfTitle', isEqualTo: widget.title)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final positions =
                        sortReadingPositionsByNewest(snapshot.data!.docs);

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
                        final position =
                            positions[index].data() as Map<String, dynamic>;
                        final page = int.tryParse(
                              position['pageNumber'].toString(),
                            ) ??
                            1;
                        final savedAt = formatSavedPositionTime(
                          position['createdAt'],
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
                              style:
                                  const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'Saved: $savedAt',
                              style:
                                  const TextStyle(color: Colors.white54),
                            ),
                            trailing: const Icon(
                              Icons.open_in_new,
                              color: Colors.greenAccent,
                              size: 18,
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
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(),
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
  },
  ),
  IconButton(
    tooltip: 'Add reader note',
    icon: const Icon(Icons.note_add, size: 20, color: Colors.greenAccent),
    
    onPressed: () {
      if (!canUseViewerTools('add_reader_note')) return;

 final noteController = TextEditingController();

 showDialog(
  barrierDismissible: false,
  context: context,
  builder: (dialogContext) {
    return PointerInterceptor(
      child: AlertDialog(
        backgroundColor: const Color(0xFF0F1117),
        title: const Text(
          'Add Note',
          style: TextStyle(color: Colors.greenAccent),
        ),
        content: TextField(
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

              final noteData = <String, dynamic>{
                'userEmail': FirebaseAuth.instance.currentUser?.email,
                'pdfTitle': widget.title,
                'selectedText': '',
                'note': noteText,
                'color': 'yellow',
                'pageNumber': currentPdfPage,
                'createdAt': FieldValue.serverTimestamp(),
              };

              final storagePath = normalizedReaderStoragePath;

              if (storagePath.isNotEmpty) {
                noteData['storagePath'] = storagePath;
              }

              await FirebaseFirestore.instance
                  .collection('reader_notes')
                  .add(noteData);

              await logReaderAction(
                action: 'add_reader_note',
                details: {
                  'noteLength': noteText.length,
                  'pageNumber': currentPdfPage,
                },
              );

              if (!dialogContext.mounted) return;

              Navigator.of(dialogContext).pop();

              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note saved successfully')),
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
).whenComplete(noteController.dispose);
},
  ),
IconButton(
  tooltip: 'Reader notes',
  icon: const Icon(Icons.list_alt, size: 20, color: Colors.greenAccent),
 
  onPressed: () async {
    if (!canUseViewerTools('view_reader_notes')) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await logReaderAction(
      action: 'view_reader_notes',
    );

    if (!mounted) return;

    showDialog(
      barrierDismissible: false,
      context: this.context,
      builder: (dialogContext) {
        return PointerInterceptor(
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F1117),
            title: const Text(
              'Reader Notes',
              style: TextStyle(color: Colors.greenAccent),
            ),
            content: SizedBox(
              width: 400,
              height: 450,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reader_notes')
                    .where('userEmail', isEqualTo: user.email)
                    .where('pdfTitle', isEqualTo: widget.title)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final notes =
                      sortReadingPositionsByNewest(snapshot.data!.docs);

                  if (notes.isEmpty) {
                    return const Center(
                      child: Text(
                        'No notes saved for this PDF yet.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  return ListView.builder(
                    primary: false,
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index].data() as Map<String, dynamic>;
                      final noteId = notes[index].id;
                      final notePage = readStoredPageNumber(
                        note['pageNumber'],
                      );
                      final noteTime = formatReaderNoteTime(note);
                      final notePreview = (note['note'] ?? '').toString();

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
                            note['note'] ?? '',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Page $notePage',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Text(
                                noteTime,
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [

    // EDIT BUTTON
    IconButton(
      tooltip: 'Edit note',
      icon: const Icon(Icons.edit, color: Colors.greenAccent),

      onPressed: () async {

        final editController =
            TextEditingController(text: note['note'] ?? '');

        final updatedNote = await showDialog(
          context: context,

          builder: (context) {
  return PointerInterceptor(
    child: AlertDialog(
              backgroundColor: const Color(0xFF0F1117),

              title: const Text(
                'Edit Note',
                style: TextStyle(color: Colors.greenAccent),
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Linked page: $notePage',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: editController,
                    maxLines: 6,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Edit your note...',
                      hintStyle: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
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
                      editController.text.trim(),
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

        editController.dispose();

        if (updatedNote == null) {
          return;
        }

        if (updatedNote.toString().isEmpty) {
          if (!context.mounted) return;

          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Write a note before saving changes.'),
            ),
          );
          return;
        }

          await FirebaseFirestore.instance
              .collection('reader_notes')
              .doc(noteId)
              .update({
            'note': updatedNote,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          await logReaderAction(
            action: 'edit_reader_note',
            details: {
              'noteId': noteId,
              'noteLength': updatedNote.toString().length,
              'pageNumber': notePage,
            },
          );

          if (!context.mounted) return;

          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note updated successfully')),
          );
      },
    ),

    // DELETE BUTTON
    IconButton(
      tooltip: 'Delete note',
      icon: const Icon(Icons.delete, color: Colors.redAccent),

      onPressed: () async {

        final confirmDelete = await showDialog(
          context: context,

          builder: (context) {
            return PointerInterceptor(
              child: AlertDialog(
                backgroundColor: const Color(0xFF0F1117),

                title: const Text(
                  'Delete Note?',
                  style: TextStyle(color: Colors.redAccent),
                ),

                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Page $notePage',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notePreview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This note will be permanently deleted.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),

                actions: [

                  TextButton(
                    onPressed: () =>
                        Navigator.pop(context, false),

                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),

                  TextButton(
                    onPressed: () =>
                        Navigator.pop(context, true),

                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            );
          },
        );

        if (confirmDelete == true) {

          await FirebaseFirestore.instance
              .collection('reader_notes')
              .doc(noteId)
              .delete();

          await logReaderAction(
            action: 'delete_reader_note',
            details: {
              'noteId': noteId,
              'pageNumber': notePage,
            },
          );

          if (!context.mounted) return;

          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note deleted')),
          );
        }
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
         HtmlElementView(viewType: viewId),

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
