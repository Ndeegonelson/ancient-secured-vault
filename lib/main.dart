import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui_web' as ui;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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

      body: Padding(
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
                color: Colors.green.withOpacity(0.12),
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
                    '• Secure PDF Streaming\n'
                    '• Text-to-Speech Audio Reading\n'
                    '• Highlights & Smart Notes\n'
                    '• Subscription Access\n'
                    '• Reading Progress Tracking\n'
                    '• Watermark Security\n'
                    '• Encrypted Content Access',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.8,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Login',
          style: TextStyle(color: Colors.greenAccent),
        ),
      ),
      body: Padding(
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

                   Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const DashboardScreen(),
  ),
);
                  } catch (e) {
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
    );
  }
}
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> freePdfFiles = [];
  List<Map<String, dynamic>> premiumPdfFiles = [];

  bool isLoading = false;
  bool isAdmin = false;
  bool hasActiveSubscription = false;
  String accessLevel = 'free';
  List<Map<String, dynamic>> userNotes = [];

  @override
  void initState() {
    super.initState();
    loadPDFs();
    checkUserRole();
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
        isAdmin = data?['role'] == 'admin';
        hasActiveSubscription = data?['subscriptionStatus'] == 'active';
        accessLevel = data?['accessLevel'] ?? 'free';
      });
    }
  }

  Future<void> uploadPDF() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null) {
        final fileBytes = result.files.first.bytes;
        final fileName = result.files.first.name;

        if (fileBytes != null) {
          await FirebaseStorage.instance
              .ref('vault_pdfs/$fileName')
              .putData(fileBytes);

          await loadPDFs();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$fileName uploaded successfully')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> loadPDFs() async {
    setState(() {
      isLoading = true;
    });

    try {
      final freeResult =
          await FirebaseStorage.instance.ref('free_pdfs').listAll();

      final premiumResult =
          await FirebaseStorage.instance.ref('vault_pdfs').listAll();

      final loadedFreeFiles = <Map<String, dynamic>>[];
      final loadedPremiumFiles = <Map<String, dynamic>>[];

      for (var item in freeResult.items) {
        final url = await item.getDownloadURL();
        loadedFreeFiles.add({
          'name': item.name,
          'url': url,
        });
      }

      for (var item in premiumResult.items) {
        final url = await item.getDownloadURL();
        loadedPremiumFiles.add({
          'name': item.name,
          'url': url,
        });
      }

      setState(() {
        freePdfFiles = loadedFreeFiles;
        premiumPdfFiles = loadedPremiumFiles;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool canAccessMainVault = isAdmin || hasActiveSubscription;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Ancient Secure Vault',
          style: TextStyle(color: Colors.greenAccent),
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.upload_file, color: Colors.greenAccent),
              onPressed: uploadPDF,
            ),           
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.greenAccent),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
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
                  : 'Free Zone Only — Subscribe to unlock the Main Vault',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),
const Text(
  'FREE ACCESS ZONE',
  style: TextStyle(
    color: Colors.orangeAccent,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 15),

ListView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: freePdfFiles.length,
  itemBuilder: (context, index) {
    return Card(
      color: Colors.orange.withOpacity(0.12),
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PDFViewerScreen(
                pdfUrl: freePdfFiles[index]['url'],
                title: freePdfFiles[index]['name'],
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

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: premiumPdfFiles.length,
              itemBuilder: (context, index) {

                return Card(
                  color: Colors.green.withOpacity(0.12),

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

                    onTap: () {

                      Navigator.push(
                        context,

                        MaterialPageRoute(
                          builder: (context) => PDFViewerScreen(
                            pdfUrl: premiumPdfFiles[index]['url'],
                            title: premiumPdfFiles[index]['name'],
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
    );
  }
}
class PDFViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const PDFViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
  });
  @override
State<PDFViewerScreen> createState() =>
    _PDFViewerScreenState();
}

class _PDFViewerScreenState
    extends State<PDFViewerScreen> {

  final TextEditingController searchController =
      TextEditingController();

final PdfViewerController pdfViewerController = PdfViewerController();
final PdfTextSearchResult pdfSearchResult = PdfTextSearchResult();

      String searchQuery = '';
      Map<String, dynamic>? latestReadingPosition;
      int currentPdfPage = 0;

      Future<void> loadLatestReadingPosition() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final snapshot = await FirebaseFirestore.instance
      .collection('reading_positions')
      .where('userEmail', isEqualTo: user.email)
      .where('pdfTitle', isEqualTo: widget.title)
      .get();

  if (snapshot.docs.isNotEmpty) {
    setState(() {
      latestReadingPosition =
          snapshot.docs.last.data();
    });
  }
}
 List<TextSpan> highlightSearchText(String text, String keyword) {
  if (keyword.isEmpty) {
    return [
      TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white54),
      ),
    ];
  }

  final spans = <TextSpan>[];
  final lowerText = text.toLowerCase();
  final lowerKeyword = keyword.toLowerCase();

  int start = 0;
  int index = lowerText.indexOf(lowerKeyword);

  while (index != -1) {
    if (index > start) {
      spans.add(
        TextSpan(
          text: text.substring(start, index),
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }

    spans.add(
      TextSpan(
        text: text.substring(index, index + keyword.length),
        style: const TextStyle(
          color: Colors.black,
          backgroundColor: Colors.greenAccent,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    start = index + keyword.length;
    index = lowerText.indexOf(lowerKeyword, start);
  }

  if (start < text.length) {
    spans.add(
      TextSpan(
        text: text.substring(start),
        style: const TextStyle(color: Colors.white54),
      ),
    );
  }

  return spans;
}

Future<List<Map<String, dynamic>>> searchPdfText(String keyword) async {
  final response = await http.get(Uri.parse(widget.pdfUrl));

  final document = PdfDocument(inputBytes: response.bodyBytes);
  final extractor = PdfTextExtractor(document);

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
    'pageNumber': i + 1,
    'text': snippet,
  });
}
  }

  document.dispose();
  return results;
}

@override
void initState() {
  super.initState();
  loadLatestReadingPosition();
}

  @override
  Widget build(BuildContext context) {
    final savedPage =
    currentPdfPage != 0 ? currentPdfPage : latestReadingPosition?['pageNumber'] ?? 0;

    final viewId =
    'pdf-viewer-${widget.pdfUrl.hashCode}-$savedPage-${DateTime.now().millisecondsSinceEpoch}';
    

    ui.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src =
    '${widget.pdfUrl}#toolbar=0&navpanes=0&scrollbar=1&page=$savedPage'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';

        return iframe;
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
  widget.title,
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
  onPressed: () {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F1117),
          title: const Text(
            'Search PDF',
            style: TextStyle(color: Colors.greenAccent),
          ),
          content: TextField(
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
  context: context,
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
        child: FutureBuilder<List<Map<String, dynamic>>>(
  future: searchPdfText(keyword),
          
          builder: (context, snapshot) {
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

    final page = data['pageNumber'] ?? 1;

    setState(() {
  currentPdfPage = page;
});
  },

  title: Text(
    'Page ${data['pageNumber']}',
    style: const TextStyle(color: Colors.white),
  ),

  subtitle: RichText(
  maxLines: 3,
  overflow: TextOverflow.ellipsis,
  text: TextSpan(
    children: highlightSearchText(
      data['text'].toString(),
      keyword,
    ),
  ),
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
    final pageController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return PointerInterceptor(
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F1117),
            title: const Text(
              'Save Reading Position',
              style: TextStyle(color: Colors.greenAccent),
            ),
            content: TextField(
              controller: pageController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Enter current page',
                hintStyle: TextStyle(color: Colors.white54),
              ),
            ),
            actions: [
             TextButton( 
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final user =
                      FirebaseAuth.instance.currentUser;

                  if (user == null) return;

                  final page =
                      int.tryParse(pageController.text) ?? 0;

                  await FirebaseFirestore.instance
                      .collection('reading_positions')
                      .add({
                    'userEmail': user.email,
                    'pdfTitle': widget.title,
                    'pageNumber': page,
                    'createdAt':
                        FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      SnackBar(
                        content: Text(
                          'Reading position saved: Page $page',
                        ),
                      ),
                    );
                  }

                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'Save',
                  style:
                      TextStyle(color: Colors.greenAccent),
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F1117),
          title: const Text(
            'Saved Reading Positions',
            style: TextStyle(color: Colors.greenAccent),
          ),
          content: SizedBox(
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

                final positions = snapshot.data!.docs;

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

                    return Card(
                      color: const Color(0xFF1A1D26),
                      child: ListTile(
                        title: Text(
                          'Saved Position ${index + 1}',
                          style:
                              const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Page: ${position['pageNumber']}',
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
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.greenAccent),
              ),
            ),
          ],
        );
      },
    );
  },
),
  IconButton(
    icon: const Icon(Icons.note_add, size: 20, color: Colors.greenAccent),
    
    onPressed: () {
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

              Navigator.of(dialogContext).pop();

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
      body: Stack(
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
                      'Protected by Ancient Secure Docs\n${FirebaseAuth.instance.currentUser?.email ?? ''}',
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