import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import '../utils/app_colors.dart';
import '../services/cloudinary_service.dart';
import '../services/notification_service.dart';
import 'video_player_screen.dart';
import 'pdf_viewer_screen.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;   // Mentor's ID (Room Owner)
  final String chatTitle;
  final String chatImage;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.chatTitle,
    required this.chatImage
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  String myId = "";
  String myName = "";
  bool isUploading = false;

  // LOGIC VARIABLES
  bool isRoomOwner = false;
  bool isMeMentorAccount = false;

  Map<String, dynamic>? replyMessage;
  File? _previewFile;
  String? _previewFileType;
  String? _previewFileName;

  // --- CACHE VARIABLES ---
  List<Map<String, dynamic>> _cachedMessages = [];
  bool _isLoadingCache = true;

  @override
  void initState() {
    super.initState();
    _getUserDetails();
    _loadCachedMessages();
  }

  void _getUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isMeMentorAccount = prefs.getBool('isMentorLoggedIn') ?? false;

      myId = isMeMentorAccount
          ? (prefs.getString('mentorId') ?? "unknown_mentor")
          : (prefs.getString('userId') ?? "unknown_student");

      myName = isMeMentorAccount
          ? (prefs.getString('mentorName') ?? "Mentor")
          : (prefs.getString('userName') ?? "Student");

      // Check: Kia main is room ka maalik hoon?
      if (myId == widget.roomId) {
        isRoomOwner = true;
      } else {
        isRoomOwner = false;
      }
    });
  }

  // --- CACHE LOGIC ---
  Future<void> _loadCachedMessages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString('chat_cache_${widget.roomId}');

    if (cachedData != null) {
      List<dynamic> decoded = jsonDecode(cachedData);
      setState(() {
        _cachedMessages = decoded.cast<Map<String, dynamic>>();
        _isLoadingCache = false;
      });
    } else {
      setState(() => _isLoadingCache = false);
    }
  }

  Future<void> _saveMessagesToCache(List<QueryDocumentSnapshot> docs) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var limitedDocs = docs.take(50).toList();

    List<Map<String, dynamic>> messagesToSave = limitedDocs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['timestamp'] is Timestamp) {
        data['timestamp'] = (data['timestamp'] as Timestamp).millisecondsSinceEpoch;
      }
      data['docId'] = doc.id;
      return data;
    }).toList();

    await prefs.setString('chat_cache_${widget.roomId}', jsonEncode(messagesToSave));
  }

  // --- HELPER FUNCTIONS ---
  Future<void> _launchExternalURL(String url) async {
    if (url.isEmpty) return;
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not open file: $e")));
    }
  }

  void _viewFullMedia(String url, String type, String fileName) {
    if (type == 'image') {
      showDialog(context: context, builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          Center(child: InteractiveViewer(child: Image.network(url))),
          Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)))
        ]),
      ));
    } else if (type == 'video') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => VideoPlayerScreen(videoUrl: url)));
    } else if (type == 'doc') {
      if (fileName.toLowerCase().contains('.pdf') || url.toLowerCase().contains('.pdf')) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => PdfViewerScreen(pdfUrl: url, fileName: fileName)));
      } else {
        _launchExternalURL(url);
      }
    }
  }

  // --- MARK AS READ LOGIC ---
  void _markMessagesAsRead(List<QueryDocumentSnapshot> docs) {
    WriteBatch batch = _firestore.batch();
    bool needsUpdate = false;

    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      // Sirf wo messages jo maine nahi bheje, unhe read mark kro
      if (data['senderId'] != myId && (data['isRead'] == null || data['isRead'] == false)) {
        batch.update(doc.reference, {'isRead': true});
        needsUpdate = true;
      }
    }
    if (needsUpdate) {
      batch.commit();
    }
  }

  // --- RATING LOGIC ---
  Future<void> _checkAndShowRatingDialog() async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow)));
    try {
      var response = await http.post(Uri.parse('https://techrisepk.com/mentor/mentorauth/check_rating.php'), body: {'mentor_id': widget.roomId, 'student_id': myId});
      Navigator.pop(context);
      var data = jsonDecode(response.body);
      if (data['status'] == 'exists') {
        _showResponseDialog("Already Rated", "You have already submitted a rating. Ratings cannot be changed.", false);
      } else {
        _showStarRatingDialog();
      }
    } catch (e) {
      Navigator.pop(context);
      _showResponseDialog("Error", "Could not verify rating status.", false);
    }
  }

  void _showResponseDialog(String title, String message, bool isSuccess) {
    showDialog(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), title: Row(children: [Icon(isSuccess ? Icons.check_circle : Icons.info, color: isSuccess ? Colors.green : AppColors.primaryBlack), const SizedBox(width: 10), Text(title, style: TextStyle(color: isSuccess ? Colors.green : AppColors.primaryBlack, fontWeight: FontWeight.bold, fontSize: 18))]), content: Text(message, style: const TextStyle(fontSize: 16)), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK", style: TextStyle(color: AppColors.primaryBlack, fontWeight: FontWeight.bold)))]));
  }

  void _showStarRatingDialog() {
    showDialog(context: context, builder: (context) {
      return AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Center(child: Text("Rate Session", style: TextStyle(fontWeight: FontWeight.bold))), content: Column(mainAxisSize: MainAxisSize.min, children: [const Text("How was your experience?", textAlign: TextAlign.center), const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (index) { return IconButton(onPressed: () async { Navigator.pop(context); await http.post(Uri.parse('https://techrisepk.com/mentor/mentorauth/rate_mentor.php'), body: {'mentor_id': widget.roomId.trim(), 'student_id': myId.trim(), 'rating': (index + 1).toString().trim()}); _showResponseDialog("Thank You", "Feedback submitted!", true); }, icon: const Icon(Icons.star_border, size: 35, color: AppColors.primaryYellow), padding: EdgeInsets.zero, constraints: const BoxConstraints()); }))]));
    });
  }

  // --- SCROLL & MEDIA LOGIC ---
  void _scrollToMessage(String messageId, List<Map<String, dynamic>> allMessages) {
    int index = allMessages.indexWhere((msg) => msg['docId'] == messageId);
    if (index != -1) {
      double position = index * 100.0; 
      _scrollController.animateTo(position, duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Message too old to locate")));
    }
  }

  Future<void> _pickFile(String type) async {
    XFile? picked;
    FilePickerResult? result;
    try {
      if (type == 'image' || type == 'camera') {
        picked = await _picker.pickImage(source: type == 'camera' ? ImageSource.camera : ImageSource.gallery, imageQuality: 70);
      } else if (type == 'video') {
        picked = await _picker.pickVideo(source: ImageSource.gallery);
      } else if (type == 'doc') {
        result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']);
      }
      if (picked != null) {
        setState(() { _previewFile = File(picked!.path); _previewFileType = type == 'camera' ? 'image' : type; _previewFileName = type == 'video' ? "Video File" : "Image"; });
      } else if (result != null && result.files.single.path != null) {
        setState(() { _previewFile = File(result!.files.single.path!); _previewFileType = 'doc'; _previewFileName = result.files.single.name; });
      }
    } catch (e) { print("Pick Error: $e"); }
  }

  Future<void> _sendMediaMessage() async {
    if (_previewFile == null) return;
    setState(() => isUploading = true);
    String? url;
    if (_previewFileType == 'image') url = await _cloudinaryService.uploadImage(XFile(_previewFile!.path));
    else if (_previewFileType == 'video') url = await _cloudinaryService.uploadVideo(XFile(_previewFile!.path));
    else if (_previewFileType == 'doc') url = await _cloudinaryService.uploadDocument(_previewFile!);

    if (url != null) {
      _sendMessage(type: _previewFileType!, url: url, fileName: _previewFileName, customText: _msgController.text.trim());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload Failed")));
    }
    setState(() { isUploading = false; _previewFile = null; _previewFileType = null; _msgController.clear(); });
  }

  void _sendMessage({String type = 'text', String? url, String? fileName, String? customText}) async {
    String textToSend = customText ?? _msgController.text.trim();
    if (textToSend.isEmpty && type == 'text') return;
    if (type == 'text') _msgController.clear();

    await _firestore.collection('chat_rooms').doc(widget.roomId).collection('messages').add({
      'text': textToSend,
      'mediaUrl': url ?? "",
      'fileName': fileName ?? "",
      'type': type,
      'senderId': myId,
      'senderName': myName,
      'isMentor': isMeMentorAccount,
      'timestamp': FieldValue.serverTimestamp(),
      'pinned': false,
      'isRead': false,
      'replyTo': replyMessage != null ? {'text': replyMessage!['type'] == 'text' ? replyMessage!['text'] : "Media File", 'sender': replyMessage!['senderName']} : null,
    });

    try {
      String role = isMeMentorAccount ? 'mentor' : 'student';
      String notifTitle = isMeMentorAccount ? "New Update from Mentor" : "$myName sent a message";
      String notifBody = (type == 'text') ? textToSend : "Sent a ${type.toUpperCase()} file 📁";
      NotificationService.sendNotification(senderRole: role, roomId: widget.roomId, title: notifTitle, body: notifBody, type: type);
    } catch (e) { print("Notification Error: $e"); }
    setState(() { replyMessage = null; });
  }

  void _deleteMessage(String docId) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Delete Message?"), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")), TextButton(onPressed: () { _firestore.collection('chat_rooms').doc(widget.roomId).collection('messages').doc(docId).delete(); Navigator.pop(context); }, child: const Text("Delete", style: TextStyle(color: Colors.red)))]));
  }

  void _togglePin(String docId, bool currentStatus) {
    if (!isRoomOwner) return;
    _firestore.collection('chat_rooms').doc(widget.roomId).collection('messages').doc(docId).update({'pinned': !currentStatus});
  }

  @override
  Widget build(BuildContext context) {
    if (_previewFile != null) return _buildPreviewScreen();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlack,
        iconTheme: const IconThemeData(color: AppColors.primaryYellow),
        title: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: Colors.grey, child: ClipOval(child: (widget.chatImage.isNotEmpty && widget.chatImage != "null") ? Image.network(widget.chatImage, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 20, color: Colors.white)) : const Icon(Icons.person, size: 20, color: Colors.white))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.chatTitle, style: const TextStyle(color: AppColors.primaryYellow, fontSize: 16, fontWeight: FontWeight.bold)), const Text("Official Chat Room", style: TextStyle(color: Colors.white54, fontSize: 10))])),
        ]),
        actions: [
          if (!isRoomOwner)
            IconButton(onPressed: _checkAndShowRatingDialog, icon: const Icon(Icons.star_rate_rounded, color: AppColors.primaryYellow), tooltip: "Rate Mentor")
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('chat_rooms').doc(widget.roomId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          List<Map<String, dynamic>> messagesToShow = [];
          if (snapshot.hasData) {
            _markMessagesAsRead(snapshot.data!.docs);
            _saveMessagesToCache(snapshot.data!.docs);
            messagesToShow = snapshot.data!.docs.map((doc) {
              var d = doc.data() as Map<String, dynamic>;
              d['docId'] = doc.id;
              return d;
            }).toList();
          } else {
            messagesToShow = _cachedMessages;
          }

          if (messagesToShow.isEmpty && !snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow));
          }

          Map<String, dynamic>? pinnedMsg;
          try { pinnedMsg = messagesToShow.firstWhere((d) => d['pinned'] == true); } catch (e) { pinnedMsg = null; }

          return Column(
            children: [
              if (pinnedMsg != null)
                GestureDetector(onTap: () => _scrollToMessage(pinnedMsg!['docId'], messagesToShow), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), color: AppColors.primaryYellow.withOpacity(0.15), child: Row(children: [const Icon(Icons.push_pin, size: 16, color: Colors.orange), const SizedBox(width: 10), Expanded(child: Text("Pinned: ${pinnedMsg['text']}", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12))), if(isRoomOwner) GestureDetector(onTap: () => _togglePin(pinnedMsg!['docId'], true), child: const Icon(Icons.close, size: 18, color: Colors.grey))]))),

              Expanded(
                child: ListView.builder(
                  controller: _scrollController, reverse: true,
                  itemCount: messagesToShow.length,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (context, index) {
                    var data = messagesToShow[index];
                    Timestamp ts;
                    if (data['timestamp'] is int) {
                      ts = Timestamp.fromMillisecondsSinceEpoch(data['timestamp']);
                    } else if (data['timestamp'] is Timestamp) {
                      ts = data['timestamp'];
                    } else {
                      ts = Timestamp.now();
                    }
                    String docId = data['docId'] ?? "";
                    bool isMe = data['senderId'] == myId;
                    return GestureDetector(
                      onLongPress: () { if (docId.isNotEmpty) { _showOptions(context, docId, isMe, data['pinned'] ?? false, data); } },
                      child: _buildMessageBubble(data, isMe, ts),
                    );
                  },
                ),
              ),

              if (replyMessage != null) Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade300))), child: Row(children: [Container(width: 4, height: 40, color: AppColors.primaryYellow), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(replyMessage!['senderName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryYellow)), Text(replyMessage!['type'] == 'text' ? replyMessage!['text'] : "📷 Media", maxLines: 1, overflow: TextOverflow.ellipsis)])), IconButton(onPressed: () => setState(() => replyMessage = null), icon: const Icon(Icons.close))])),
              if (isUploading) const LinearProgressIndicator(color: AppColors.primaryYellow),
              _buildInputArea(),
            ],
          );
        },
      ),
    );
  }

  void _showOptions(BuildContext context, String docId, bool isMe, bool isPinned, Map<String, dynamic> data) {
    showModalBottomSheet(context: context, builder: (ctx) => Container(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (isRoomOwner) ListTile(leading: const Icon(Icons.reply), title: const Text("Reply"), onTap: () { Navigator.pop(context); setState(() => replyMessage = data); }),
      if (isRoomOwner) ListTile(leading: const Icon(Icons.push_pin), title: Text(isPinned ? "Unpin" : "Pin"), onTap: () { Navigator.pop(context); _togglePin(docId, isPinned); }),
      if (isMe || isRoomOwner) ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("Delete Message", style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(context); _deleteMessage(docId); }),
    ])));
  }

  Widget _buildPreviewScreen() {
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() { _previewFile = null; }))), body: Column(children: [Expanded(child: Center(child: _previewFileType == 'image' ? Image.file(_previewFile!) : Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.description, size: 80, color: Colors.white), Text("File Ready", style: TextStyle(color: Colors.white))]))), Container(padding: const EdgeInsets.all(10), color: Colors.black54, child: Row(children: [Expanded(child: TextField(controller: _msgController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Add a caption...", hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none))), IconButton(icon: isUploading ? const CircularProgressIndicator() : const Icon(Icons.send, color: AppColors.primaryYellow), onPressed: isUploading ? null : _sendMediaMessage)]))]));
  }

  Widget _buildInputArea() {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), color: Colors.white, child: SafeArea(child: Row(children: [IconButton(icon: const Icon(Icons.add_circle, color: AppColors.primaryBlack, size: 28), onPressed: _showAttachmentSheet), Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 15), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(25)), child: TextField(controller: _msgController, decoration: const InputDecoration(hintText: "Type a message...", border: InputBorder.none)))), const SizedBox(width: 8), GestureDetector(onTap: () => _sendMessage(), child: const CircleAvatar(backgroundColor: AppColors.primaryYellow, child: Icon(Icons.send, color: AppColors.primaryBlack, size: 20)))])));
  }

  // --- UPDATED MESSAGE BUBBLE (STRICT OWNER LOGIC) ---
  Widget _buildMessageBubble(Map<String, dynamic> data, bool isMe, Timestamp timestamp) {
    String senderId = data['senderId'] ?? "";
    bool isMessageFromRoomOwner = (senderId == widget.roomId); // STRICT CHECK
    bool isRead = data['isRead'] ?? false;

    Color bubbleColor;
    Color textColor;
    
    if (isMessageFromRoomOwner) {
      bubbleColor = AppColors.primaryYellow; // OWNER = YELLOW
      textColor = AppColors.primaryBlack;    
    } else if (isMe) {
      bubbleColor = AppColors.primaryBlack;  // ME = BLACK
      textColor = Colors.white;
    } else {
      bubbleColor = Colors.white;            // OTHERS = WHITE
      textColor = Colors.black87;
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, 
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4), 
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), 
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, 
          children: [
            if (data['replyTo'] != null) Container(padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 2), decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: isMe ? AppColors.primaryYellow : AppColors.primaryBlack, width: 3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data['replyTo']['sender'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)), Text(data['replyTo']['text'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10))])),
            
            Container(
              padding: const EdgeInsets.all(12), 
              decoration: BoxDecoration(
                color: bubbleColor, 
                borderRadius: BorderRadius.only(topLeft: const Radius.circular(15), topRight: const Radius.circular(15), bottomLeft: isMe ? const Radius.circular(15) : const Radius.circular(0), bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(15)), 
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 3)]
              ), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  // SENDER NAME (Sirf agar doosra banda ho, ya Owner ho tab dikhana)
                  if (!isMe || isMessageFromRoomOwner) Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data['senderName'], 
                        style: TextStyle(
                          fontSize: 11, 
                          fontWeight: FontWeight.bold, 
                          color: isMessageFromRoomOwner ? Colors.black87 : Colors.grey
                        )
                      ),
                      if(isMessageFromRoomOwner) const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.verified, size: 12, color: Colors.blue),
                      )
                    ],
                  ),
                  
                  if (data['type'] == 'text') Text(data['text'], style: TextStyle(color: textColor)), 
                  
                  if (data['type'] == 'image') GestureDetector(onTap: () => _viewFullMedia(data['mediaUrl'], 'image', ''), child: Container(constraints: const BoxConstraints(maxHeight: 250, minHeight: 150), margin: const EdgeInsets.symmetric(vertical: 5), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(data['mediaUrl'], fit: BoxFit.cover, width: double.infinity)))),
                  if (data['type'] == 'video' || data['type'] == 'doc') GestureDetector(onTap: () => _viewFullMedia(data['mediaUrl'], data['type'], data['fileName'] ?? ""), child: Container(constraints: const BoxConstraints(maxHeight: 250, minHeight: 150), width: double.infinity, margin: const EdgeInsets.symmetric(vertical: 5), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(8)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(data['type'] == 'video' ? Icons.play_circle_fill : Icons.description, color: AppColors.primaryYellow, size: 50), const SizedBox(height: 10), Text(data['type'] == 'video' ? "Watch Video" : "View Document", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), if(data['fileName'] != null) Text(data['fileName'], style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)]))),
                  if (data['type'] != 'text' && data['text'] != null && data['text'].toString().isNotEmpty) Text(data['text'], style: TextStyle(color: textColor, fontSize: 12)),
                  
                  const SizedBox(height: 5),
                  Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(DateFormat('hh:mm a').format(timestamp.toDate()), style: TextStyle(fontSize: 9, color: textColor.withOpacity(0.7))),
                    if (isMe) ...[
                      const SizedBox(width: 5),
                      Icon(Icons.done_all, size: 14, color: isRead ? Colors.blue : (isMessageFromRoomOwner ? Colors.black54 : Colors.grey))
                    ]
                  ])
                ]
              )
            )
          ]
        )
      )
    );
  }

  void _showAttachmentSheet() { showModalBottomSheet(context: context, builder: (ctx) => Container(height: 150, color: Colors.white, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_iconBtn(Icons.camera_alt, "Camera", () { Navigator.pop(context); _pickFile('camera'); }), _iconBtn(Icons.image, "Gallery", () { Navigator.pop(context); _pickFile('image'); }), _iconBtn(Icons.videocam, "Video", () { Navigator.pop(context); _pickFile('video'); }), _iconBtn(Icons.attach_file, "Doc", () { Navigator.pop(context); _pickFile('doc'); })]))); }
  Widget _iconBtn(IconData icon, String label, VoidCallback onTap) { return GestureDetector(onTap: onTap, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 30, color: AppColors.primaryBlack), Text(label)])); }
}