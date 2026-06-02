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
              'Search Results: $keyword',
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
                              'No matching results found.',
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

  const PDFViewerScreen({
  super.key,
  required this.pdfUrl,
  required this.title,
  this.initialPage = 0,
  this.initialSearchQuery = '',
  this.accessLevel = 'free',
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
      late final String readerSessionId;

String get shortReaderSessionId {
  if (readerSessionId.length <= 8) {
    return readerSessionId;
  }

  return readerSessionId.substring(readerSessionId.length - 8);
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
  await logReaderSessionLifecycle('started');
  loadLatestReadingPosition();
}

Future<void> logReaderAccessAttempt({
  required bool allowed,
  required UserAccessState userAccess,
}) async {
  final user = FirebaseAuth.instance.currentUser;

  try {
    await FirebaseFirestore.instance.collection('reader_access_logs').add({
      'userEmail': user?.email,
      'pdfTitle': widget.title,
      'readerSessionId': readerSessionId,
      'documentAccessLevel': widget.accessLevel,
      'userAccessLevel': userAccess.accessLevel,
      'isAdmin': userAccess.isAdmin,
      'hasActiveSubscription': userAccess.hasActiveSubscription,
      'allowed': allowed,
      'createdAt': FieldValue.serverTimestamp(),
    });
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
    await FirebaseFirestore.instance.collection('reader_activity_logs').add({
      'userEmail': user?.email,
      'pdfTitle': widget.title,
      'readerSessionId': readerSessionId,
      'documentAccessLevel': widget.accessLevel,
      'action': action,
      'details': details,
      'createdAt': FieldValue.serverTimestamp(),
    });
  } catch (_) {
    // Activity logging should not interrupt the reader experience.
  }
}

Future<void> logReaderSessionLifecycle(String event) async {
  final user = FirebaseAuth.instance.currentUser;

  try {
    await FirebaseFirestore.instance.collection('reader_session_logs').add({
      'userEmail': user?.email,
      'pdfTitle': widget.title,
      'readerSessionId': readerSessionId,
      'documentAccessLevel': widget.accessLevel,
      'event': event,
      'createdAt': FieldValue.serverTimestamp(),
    });
  } catch (_) {
    // Session logging should not interrupt the reader experience.
  }
}

bool canUseViewerTools() {
  if (canViewDocument) return true;

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
      openPdfPage(savedPage);
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
}) {
  final safePageNumber = pageNumber < 1 ? 1 : pageNumber;
  currentPdfPage = safePageNumber;
  currentSearchQuery = searchQuery ?? currentSearchQuery;

  pdfIframe?.src = buildPdfViewerUrl(
    pageNumber: currentPdfPage,
    searchQuery: currentSearchQuery,
  );
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
final lowerKeyword = keyword.toLowerCase();
final matchIndex = lowerText.indexOf(lowerKeyword);

if (matchIndex != -1) {
  final snippetStart = matchIndex - 80 < 0 ? 0 : matchIndex - 80;
  final snippetEnd =
      matchIndex + 180 > text.length ? text.length : matchIndex + 180;

  final snippet = text.substring(snippetStart, snippetEnd);

  results.add({
  'pdfTitle': widget.title,
  'pdfUrl': widget.pdfUrl,
  'pageNumber': i + 1,
  'text': snippet,
});
}
  }

    await logReaderAction(
      action: 'internal_pdf_search',
      details: {
        'keywordLength': keyword.length,
        'resultCount': results.length,
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
    logReaderSessionLifecycle('ended');
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
        title: Text(
  widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.greenAccent),
        ),
        iconTheme: const IconThemeData(color: Colors.greenAccent),
        actions: [
        IconButton(
  icon: const Icon(
    Icons.search,
    size: 20,
    color: Colors.greenAccent,
  ),

 onPressed: () async {
    if (!canUseViewerTools()) return;

  showDialog(
      context: this.context,
      builder: (dialogContext) {

        return PointerInterceptor(
  child: AlertDialog(
          backgroundColor: const Color(0xFF0F1117),
          title: const Text(
            'Search PDF',
            style: TextStyle(color: Colors.greenAccent),
          ),
          content: TextField(
               enabled: true,
               readOnly: false,
               autofocus: true,
            controller: searchController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter keyword',
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
          actions: [
            PointerInterceptor(
  child: TextButton(
              onPressed: () {
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
        'Search Results: $keyword',
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
                  'No matching results found.',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            return ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final data = results[index];

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
    );
  },

  title: Text(
    'Page ${data['pageNumber']}',
    style: const TextStyle(color: Colors.white),
  ),
subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

    Text(
      'Page ${data['pageNumber']}',
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
              },
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
  icon: const Icon(
    Icons.bookmark_add,
    size: 20,
    color: Colors.greenAccent,
  ),
  onPressed: () async {
    if (!canUseViewerTools()) return;

    final pageController = TextEditingController(
      text: currentPdfPage.toString(),
    );

    showDialog(
      context: this.context,
      builder: (dialogContext) {
        return PointerInterceptor(
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F1117),
            title: const Text(
              'Save Reading Position',
              style: TextStyle(color: Colors.greenAccent),
            ),
            content: PointerInterceptor(
              child: TextField(
                controller: pageController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Enter current page',
                  hintStyle: TextStyle(color: Colors.white54),
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
                    if (!canUseViewerTools()) return;

                    final page =
                        int.tryParse(pageController.text.trim()) ?? 0;

                    final saved =
                        await saveReadingPositionPage(page);

                    if (!dialogContext.mounted) return;

                    if (saved) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text(
                    'Save',
                    style:
                        TextStyle(color: Colors.greenAccent),
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
  icon: const Icon(Icons.history, size: 20, color: Colors.greenAccent),
 
  onPressed: () async {
    if (!canUseViewerTools()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: this.context,
      builder: (dialogContext) {
        return PointerInterceptor(
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F1117),
            title: const Text(
              'Saved Reading Positions',
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
                          'No saved positions yet.',
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

                        return Card(
                          color: const Color(0xFF1A1D26),
                          child: ListTile(
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              openPdfPage(page);
                            },
                            title: Text(
                              'Saved Position ${index + 1}',
                              style:
                                  const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'Page: $page',
                              style:
                                  const TextStyle(color: Colors.white54),
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
    icon: const Icon(Icons.note_add, size: 20, color: Colors.greenAccent),
    
    onPressed: () {
      if (!canUseViewerTools()) return;

 showDialog(
  barrierDismissible: false,
  context: context,
  builder: (dialogContext) {
    final noteController = TextEditingController();

    return PointerInterceptor(
      child: AlertDialog(
        backgroundColor: const Color(0xFF0F1117),
        title: const Text(
          'Add Reader Note',
          style: TextStyle(color: Colors.greenAccent),
        ),
        content: TextField(
          autofocus: true,
          controller: noteController,
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Write your note here...',
            hintStyle: TextStyle(color: Colors.white54),
            border: OutlineInputBorder(),
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

              if (noteText.isEmpty) return;

              await FirebaseFirestore.instance.collection('reader_notes').add({
                'userEmail': FirebaseAuth.instance.currentUser?.email,
                'pdfTitle': widget.title,
                'selectedText': '',
                'note': noteText,
                'color': 'yellow',
                'pageNumber': 0,
                'createdAt': FieldValue.serverTimestamp(),
              });

              await logReaderAction(
                action: 'add_reader_note',
                details: {
                  'noteLength': noteText.length,
                  'pageNumber': 0,
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
);
},
  ),
IconButton(
  icon: const Icon(Icons.list_alt, size: 20, color: Colors.greenAccent),
 
  onPressed: () async {
    if (!canUseViewerTools()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) {
        return PointerInterceptor(
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F1117),
            title: const Text(
              'My Reader Notes',
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

                  final notes = snapshot.data!.docs;

                  if (notes.isEmpty) {
                    return const Center(
                      child: Text(
                        'No notes saved for this document yet.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  return ListView.builder(
                    primary: false,
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index].data() as Map<String, dynamic>;

                      return Card(
                        color: const Color(0xFF1A1D26),
                        child: ListTile(
                          title: Text(
                            note['note'] ?? '',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'Color: ${note['color'] ?? 'yellow'}',
                            style: const TextStyle(color: Colors.white54),
                          ),
                        trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [

    // EDIT BUTTON
    IconButton(
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

              content: TextField(
                controller: editController,
                maxLines: 6,

                style: const TextStyle(color: Colors.white),

                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Edit your note...',
                  hintStyle: TextStyle(color: Colors.white54),
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

        if (updatedNote != null &&
            updatedNote.toString().isNotEmpty) {

          await FirebaseFirestore.instance
              .collection('reader_notes')
              .doc(notes[index].id)
              .update({
            'note': updatedNote,
          });
        }
      },
    ),

    // DELETE BUTTON
    IconButton(
      icon: const Icon(Icons.delete, color: Colors.redAccent),

      onPressed: () async {

        final confirmDelete = await showDialog(
          context: context,

          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F1117),

              title: const Text(
                'Delete Note?',
                style: TextStyle(color: Colors.redAccent),
              ),

              content: const Text(
                'Are you sure you want to permanently delete this note?',
                style: TextStyle(color: Colors.white70),
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
            );
          },
        );

        if (confirmDelete == true) {

          await FirebaseFirestore.instance
              .collection('reader_notes')
              .doc(notes[index].id)
              .delete();
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
                      'Protected by Ancient Secure Docs\n'
                      '${FirebaseAuth.instance.currentUser?.email ?? ''}\n'
                      'Session: $shortReaderSessionId',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
