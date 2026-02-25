import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'logic/scan_logic.dart';
import 'logic/history_logic.dart';
import 'logic/barcode_service.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  // Register Test Device
  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(testDeviceIds: ['8146FEDE5292B91FCF1B9F3301084A74']),
  );
  runApp(const PureScanApp());
}

class PureScanApp extends StatelessWidget {
  const PureScanApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF10B981)),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _image;
  bool _isScanning = false;
  String _statusMessage = "Point at ingredients";
  
  // state variable for the complex result
  AnalysisResult? _currentResult;
  
  final ImagePicker _picker = ImagePicker();
  BannerAd? _nativeStyleAd;
  bool _isNativeAdLoaded = false;
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    _loadNativeStyleAd();
    _loadInterstitialAd();
  }

  void _loadNativeStyleAd() {
    _nativeStyleAd = BannerAd(
      adUnitId: Platform.isAndroid ? 'ca-app-pub-2738077629676286/4857179816' : 'ca-app-pub-2738077629676286/4857179816',
      size: AdSize.largeBanner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isNativeAdLoaded = true),
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    _nativeStyleAd!.load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: Platform.isAndroid ? 'ca-app-pub-2738077629676286/4843354488' : 'ca-app-pub-2738077629676286/4843354488',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd(); 
            },
          );
        },
        onAdFailedToLoad: (err) {},
      ),
    );
  }

  Future<void> _pickAndScanText(ImageSource source) async => await _pickImageGeneral(source, isBarcodeMode: false);
  Future<void> _pickAndScanBarcode() async => await _pickImageGeneral(ImageSource.camera, isBarcodeMode: true);

  Future<void> _pickImageGeneral(ImageSource source, {required bool isBarcodeMode}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _isScanning = true;
          _statusMessage = isBarcodeMode ? "Reading Barcode..." : "Reading Text...";
        });
        await Future.delayed(const Duration(seconds: 2));
        if (isBarcodeMode) {
          await _processBarcode(_image!);
        } else {
          await _processText(_image!);
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _processText(File image) async {
    final inputImage = InputImage.fromFile(image);
    final textRecognizer = TextRecognizer();
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      _finalizeAnalysis(recognizedText.text, image);
    } catch (e) {
      setState(() => _isScanning = false);
    } finally {
      textRecognizer.close();
    }
  }

  Future<void> _processBarcode(File image) async {
    final inputImage = InputImage.fromFile(image);
    final barcodeScanner = BarcodeScanner();
    try {
      final barcodes = await barcodeScanner.processImage(inputImage);
      if (barcodes.isEmpty) {
        _showError("No barcode found.");
        return;
      }
      String? code = barcodes.first.rawValue;
      if (code == null) {
        _showError("Could not read barcode.");
        return;
      }
      setState(() => _statusMessage = "Fetching Ingredients...");
      String? ingredientsText = await BarcodeService.getIngredientsFromBarcode(code);
      if (ingredientsText == null) {
        _showError("Product not in database. Use TEXT Camera.");
        return;
      }
      _finalizeAnalysis(ingredientsText, image);
    } catch (e) {
      _showError("Internet required.");
    } finally {
      barcodeScanner.close();
    }
  }

  void _finalizeAnalysis(String text, File image) async {
    AnalysisResult result = ScanLogic.analyzeText(text);
    
    // Save for History
    List<String> allIssues = [...result.haramFound, ...result.meatFound, ...result.mushboohFound];
    await HistoryLogic.saveScan(allIssues, image);

    setState(() {
      _currentResult = result;
      _isScanning = false;
    });
    _showResultsModal();
  }

  void _showError(String msg) {
    setState(() => _isScanning = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showResultsModal() {
    if (_currentResult == null) return;

    // Haptics based on severity
    if (_currentResult!.status == ScanStatus.safe) {
       HapticFeedback.mediumImpact();
    } else {
       HapticFeedback.heavyImpact();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ResultSheet(
        result: _currentResult!, 
        image: _image!
      ),
    );

    // Show Ad if Safe
    if (_currentResult!.status == ScanStatus.safe && _interstitialAd != null) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _interstitialAd!.show();
      });
    }
  }

  @override
  void dispose() {
    _nativeStyleAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 4.seconds, begin: const Offset(1,1), end: const Offset(1.2,1.2)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                height: screenHeight > 700 ? screenHeight - 50 : null, 
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Tayyib Scan", style: GoogleFonts.poppins(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w600, color: Colors.grey)),
                              Text("Is it Halal?", style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87)).animate().fadeIn().slideX(begin: -0.2, end: 0),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                            child: IconButton(
                              icon: const Icon(Icons.history, color: Color(0xFF10B981)),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen())),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: screenHeight * 0.30,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                        ),
                        child: _isScanning && _image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(_image!, fit: BoxFit.cover),
                                    const ScannerAnimation(),
                                    Container(color: Colors.black26),
                                    Center(child: Text(_statusMessage, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5))).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 600.ms).fadeOut(delay: 600.ms),
                                  ],
                                ),
                              ).animate().fadeIn()
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.center_focus_strong_rounded, size: 50, color: Colors.grey[300]),
                                  const SizedBox(height: 10),
                                  Text("Point at ingredients list", style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14)),
                                ],
                              ),
                      ),
                      Row(
                        children: [
                          Expanded(child: _buildBigButton(Icons.qr_code, "Barcode", Colors.blueGrey, () => _pickAndScanBarcode())),
                          const SizedBox(width: 10),
                          Expanded(child: _buildBigButton(Icons.description, "Text", Colors.black, () => _pickAndScanText(ImageSource.camera))),
                          const SizedBox(width: 10),
                          Expanded(child: _buildBigButton(Icons.photo, "Upload", const Color(0xFF10B981), () => _pickAndScanText(ImageSource.gallery))),
                        ],
                      ).animate().slideY(begin: 1, end: 0, curve: Curves.easeOutQuad, duration: 600.ms),
                      if (_isNativeAdLoaded)
                        Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]),
                          child: ClipRRect(borderRadius: BorderRadius.circular(12), child: AdWidget(ad: _nativeStyleAd!)),
                        ).animate().fadeIn(duration: 800.ms)
                      else
                        Container(height: 100, width: double.infinity, color: Colors.transparent),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBigButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
          ]),
      ),
    );
  }
}

// ScannerAnimation
class ScannerAnimation extends StatelessWidget {
  const ScannerAnimation({super.key});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity, height: 2,
          decoration: BoxDecoration(color: const Color(0xFF10B981), boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.8), blurRadius: 10, spreadRadius: 2)]),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).slideY(begin: -150, end: 150, duration: 2.seconds);
      },
    );
  }
}


// RESULT SHEET

class ResultSheet extends StatelessWidget {
  final AnalysisResult result;
  final File image;
  const ResultSheet({super.key, required this.result, required this.image});

  @override
  Widget build(BuildContext context) {
    
    // DETERMINE THE STATUS AND COLORS
    String title = "Halal Safe";
    String subTitle = "No forbidden ingredients found.";
    Color color = const Color(0xFF10B981); // Green
    IconData icon = Icons.check_circle_rounded;

    if (result.status == ScanStatus.haram) {
      title = "Haram Detected";
      subTitle = "Avoid this product.";
      color = const Color(0xFFEF4444); // Red
      icon = Icons.block_rounded;
    } else if (result.status == ScanStatus.meatCheck) {
      title = "Ritual Slaughter";
      subTitle = "Check for Halal/Zabiha Logo.";
      color = Colors.orange;
      icon = Icons.info_rounded;
    } else if (result.status == ScanStatus.mushbooh) {
      title = "Mushbooh (Doubt)";
      subTitle = "Ingredients source unclear.";
      color = Colors.amber.shade700;
      icon = Icons.warning_rounded;
    }

    // combine all issues for the list
    List<String> displayList = [];
    if (result.status == ScanStatus.haram) displayList = result.haramFound;
    if (result.status == ScanStatus.meatCheck) displayList = result.meatFound;
    if (result.status == ScanStatus.mushbooh) displayList = result.mushboohFound;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 30),
            
            // ANIMATED STATUS ICON
            Icon(icon, size: 100, color: color)
                .animate().scale(duration: 600.ms, curve: Curves.elasticOut)
                .then(delay: 200.ms).shake(offset: result.status == ScanStatus.safe ? Offset.zero : const Offset(10, 0)),
            
            const SizedBox(height: 20),
            Text(title, style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: color)).animate().fadeIn().slideY(begin: 0.5, end: 0),
            Text(subTitle, style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 30),
            
            Expanded(
              child: displayList.isEmpty
                  ? Center(child: const Text("🌿", style: TextStyle(fontSize: 50)).animate().fade().scale())
                  : ListView.builder(
                      itemCount: displayList.length,
                      itemBuilder: (context, index) {
                        return Card(
                          elevation: 0, 
                          color: color.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.3))),
                          child: ListTile(
                            leading: Icon(Icons.circle, color: color, size: 14), 
                            title: Text(displayList[index], style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                            subtitle: Text(_getDescription(displayList[index]), style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                          ),
                        ).animate().slideX(begin: 1, end: 0, delay: (index * 100).ms);
                      },
                    ),
            ),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text("Scan Again", style: TextStyle(color: Colors.white, fontSize: 16)))),
          ],
        ),
      ),
    );
  }

  // HELPER TO EXPLAIN WHY
  String _getDescription(String ingredient) {
    if (ScanLogic.haramKeywords.contains(ingredient)) return "Forbidden (Haram)";
    if (ScanLogic.meatKeywords.contains(ingredient)) return "Requires Zabiha Certification";
    if (ScanLogic.mushboohKeywords.contains(ingredient)) return "Source Unknown (Plant or Animal?)";
    return "Additive";
  }
}