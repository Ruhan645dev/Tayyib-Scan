import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../logic/history_logic.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ScanRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await HistoryLogic.getHistory();
    setState(() => _records = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("Scan History", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              HistoryLogic.clearHistory();
              setState(() => _records = []);
            },
          )
        ],
      ),
      body: _records.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey[300]),
                  Text("No scans yet", style: GoogleFonts.poppins(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _records.length,
              itemBuilder: (context, index) {
                final record = _records[index];
                final dateStr = DateFormat('MMM d, h:mm a').format(record.date);
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: record.isSafe ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                  ),
                  color: record.isSafe ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 70, height: 70,
                            child: Image.file(File(record.imagePath), fit: BoxFit.cover, errorBuilder: (c,o,s) => Icon(Icons.image, color: Colors.grey[300])),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(record.isSafe ? Icons.check_circle : Icons.cancel, color: record.isSafe ? Colors.green : Colors.red, size: 18),
                                  const SizedBox(width: 6),
                                  Text(record.isSafe ? "Halal Safe" : "Haram Detected", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: record.isSafe ? Colors.green[800] : Colors.red[800], fontSize: 15)),
                                ],
                              ),
                              Text(dateStr, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12)),
                              if (!record.isSafe) ...[
                                const SizedBox(height: 4),
                                Text(record.ingredients.take(3).join(", "), style: GoogleFonts.poppins(color: Colors.red[400], fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ]
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: (index * 50).ms).slideX();
              },
            ),
    );
  }
}