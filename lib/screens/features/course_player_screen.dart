import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_colors.dart';

class CoursePlayerScreen extends StatefulWidget {
  final String videoId; 
  final String courseId;
  final String title;
  final String desc;

  const CoursePlayerScreen({
    super.key, 
    required this.videoId, 
    required this.courseId, 
    required this.title, 
    required this.desc
  });

  @override
  State<CoursePlayerScreen> createState() => _CoursePlayerScreenState();
}

class _CoursePlayerScreenState extends State<CoursePlayerScreen> {
  YoutubePlayerController? _controller;
  Timer? _trackerTimer;
  bool _isVideoValid = false;
  double _currentProgress = 0.0;
  
  // Unique key for saving specific video progress
  String get _storageKey => 'vid_progress_${widget.videoId}';

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    String rawInput = widget.videoId.trim();
    String? finalId;

    if (rawInput.isEmpty) {
      setState(() => _isVideoValid = false);
      return;
    }

    finalId = YoutubePlayer.convertUrlToId(rawInput) ?? rawInput;

    if (finalId.isEmpty) {
      setState(() => _isVideoValid = false);
      return;
    }

    // --- 1. LOAD SAVED PROGRESS (OFFLINE) ---
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int savedSeconds = prefs.getInt(_storageKey) ?? 0;

    if (mounted) {
      setState(() {
        _isVideoValid = true;
      });
      
      _controller = YoutubePlayerController(
        initialVideoId: finalId,
        flags: YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          hideThumbnail: true,
          hideControls: false,
          enableCaption: false,
          forceHD: false,
          startAt: savedSeconds, // Yahan se video resume hogi
        ),
      );

      // --- 2. START TRACKING ---
      _trackerTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (mounted && _controller != null && _controller!.value.isPlaying) {
          _updateProgress();
        }
      });
    }
  }

  Future<void> _updateProgress() async {
    if (_controller == null) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String uId = prefs.getString('userId') ?? "0"; 

    int watched = _controller!.value.position.inSeconds;
    int total = _controller!.metadata.duration.inSeconds;

    if (total > 0) {
      double percent = (watched / total);
      if (mounted) setState(() => _currentProgress = percent);

      // --- 3. SAVE LOCALLY (Shared Preferences) ---
      // Taake agli baar banda wahin se shuru kare
      await prefs.setInt(_storageKey, watched);

      // --- 4. UPDATE SERVER ---
      try {
        await http.post(
          Uri.parse('https://techrisepk.com/mentor/courses/update_progress.php'),
          body: {
            'student_id': uId,
            'course_id': widget.courseId,
            'watched': watched.toString(),
            'total': total.toString()
          }
        );
      } catch (e) {
        print("Server Sync Error: $e");
      }
    }
  }

  @override
  void dispose() {
    _trackerTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.primaryBlack,
      body: SafeArea(
        bottom: false, 
        child: Column(
          children: [
            // --- VIDEO PLAYER AREA ---
            SizedBox(
              height: isLandscape ? MediaQuery.of(context).size.height * 0.7 : 250,
              width: double.infinity,
              child: _isVideoValid && _controller != null
                  ? YoutubePlayer(
                      controller: _controller!,
                      showVideoProgressIndicator: true,
                      progressIndicatorColor: AppColors.primaryYellow,
                      progressColors: const ProgressBarColors(
                        playedColor: AppColors.primaryYellow,
                        handleColor: AppColors.primaryYellow,
                      ),
                      onReady: () {
                         // Player ready hotay hi UI progress update karein
                         if(_controller != null) {
                           int total = _controller!.metadata.duration.inSeconds;
                           int current = _controller!.value.position.inSeconds;
                           if(total > 0) {
                             setState(() {
                               _currentProgress = current / total;
                             });
                           }
                         }
                      },
                    )
                  : Container(
                      color: Colors.black,
                      child: const Center(child: Icon(Icons.error, color: Colors.red)),
                    ),
            ),
            
            // --- DETAILS SECTION ---
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20))
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black))
                          ),
                          // Live Progress Indicator
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: _currentProgress,
                                backgroundColor: Colors.grey.shade200,
                                color: Colors.green,
                              ),
                              Text(
                                "${(_currentProgress * 100).toInt()}%",
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              )
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                         "${(_currentProgress * 100).toStringAsFixed(0)}% Watched",
                         style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      const SizedBox(height: 10),
                      const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 5),
                      Text(widget.desc, style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87)),
                      
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}