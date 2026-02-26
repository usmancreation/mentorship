import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String fileName;

  const PdfViewerScreen({super.key, required this.pdfUrl, required this.fileName});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? localPath;
  bool isDownloading = true; // Download status
  bool isPdfReady = false;   // Rendering status
  String errorMessage = "";
  int? pages = 0;

  @override
  void initState() {
    super.initState();
    loadPdf();
  }

  // --- PDF DOWNLOAD LOGIC ---
  Future<void> loadPdf() async {
    try {
      print("Downloading PDF from: ${widget.pdfUrl}"); // Debug Log

      final url = widget.pdfUrl;
      final filename = widget.fileName.isNotEmpty ? widget.fileName : "temp_document.pdf";
      
      // 1. Download Data
      final http.Response response = await http.get(Uri.parse(url));

      // DEBUG: Check File Size
      print("Download Status: ${response.statusCode}");
      print("File Size (Bytes): ${response.bodyBytes.length}");

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        setState(() {
          errorMessage = "File is empty or download failed.";
          isDownloading = false;
        });
        return;
      }

      // 2. Save File Locally
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(response.bodyBytes, flush: true);

      print("File Saved at: ${file.path}");

      // 3. Set Path
      if (mounted) {
        setState(() {
          localPath = file.path;
          isDownloading = false;
        });
      }
    } catch (e) {
      print("PDF Error: $e");
      if (mounted) {
        setState(() {
          isDownloading = false;
          errorMessage = "Error loading PDF: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.fileName, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Stack(
        children: [
          // ERROR MESSAGE
          if (errorMessage.isNotEmpty)
            Center(child: Text(errorMessage, style: const TextStyle(color: Colors.red))),

          // PDF VIEW
          if (localPath != null)
            PDFView(
              filePath: localPath!,
              enableSwipe: true,
              swipeHorizontal: false, // Vertical Scroll (Phone k liye behtar ha)
              autoSpacing: true,
              pageFling: true,
              pageSnap: false, // Smooth scrolling enable karega
              fitPolicy: FitPolicy.WIDTH, // Page ko screen ki width k hisab se set karega
              
              onRender: (pages) {
                print("PDF Rendered with $pages pages.");
                setState(() {
                  isPdfReady = true;
                  this.pages = pages;
                });
              },
              onError: (error) {
                print("PDF View Error: ${error.toString()}");
                setState(() {
                  errorMessage = error.toString();
                });
              },
              onPageError: (page, error) {
                print('Page $page Error: ${error.toString()}');
              },
            ),
          
          // LOADING INDICATOR
          if (isDownloading || !isPdfReady)
             Container(
               color: Colors.white,
               child: const Center(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     CircularProgressIndicator(color: Colors.black),
                     SizedBox(height: 10),
                     Text("Loading Document...")
                   ],
                 ),
               ),
             ),
        ],
      ),
    );
  }
}