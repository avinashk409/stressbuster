import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/audio_service.dart';
import '../widgets/voice_message_recorder.dart';
import '../widgets/voice_message_player.dart';
import 'schedule_call_screen.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String counselorName;
  final String counselorId;

  const ChatScreen({
    Key? key,
    required this.counselorName,
    required this.counselorId,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioService _audioService = AudioService();
  final currentUser = FirebaseAuth.instance.currentUser;
  bool _isTyping = false;
  bool _isRecording = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
  }

  Future<void> _markMessagesAsRead() async {
    final messages = await FirebaseFirestore.instance
        .collection('chats')
        .where('receiverId', isEqualTo: currentUser!.uid)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in messages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    await FirebaseFirestore.instance.collection('chats').add({
      'type': 'text',
      'text': messageText,
      'senderId': currentUser!.uid,
      'receiverId': widget.counselorId,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _startRecording() async {
    try {
      await _audioService.startRecording();
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting recording: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      final filePath = await _audioService.stopRecording();
      if (filePath != null) {
        setState(() {
          _isRecording = false;
          _isUploading = true;
        });

        await _audioService.uploadVoiceMessage(filePath, widget.counselorId);
        
        setState(() {
          _isUploading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error recording voice message: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _isUploading = true;
        });

        final file = result.files.first;
        final fileName = 'attachments/${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final ref = FirebaseStorage.instance.ref().child(fileName);
        
        await ref.putData(file.bytes!);
        final downloadUrl = await ref.getDownloadURL();

        await FirebaseFirestore.instance.collection('chats').add({
          'type': 'file',
          'fileName': file.name,
          'fileUrl': downloadUrl,
          'fileSize': file.size,
          'senderId': currentUser!.uid,
          'receiverId': widget.counselorId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        setState(() {
          _isUploading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading file: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(date);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('dd/MM/yy').format(date);
    }
  }

  Widget _buildMessageContent(Map<String, dynamic> msg) {
    final type = msg['type'] as String? ?? 'text';
    
    switch (type) {
      case 'voice':
        return VoiceMessagePlayer(
          audioUrl: msg['audioUrl'],
          isMe: msg['senderId'] == currentUser!.uid,
        );
      case 'file':
        return InkWell(
          onTap: () {
            // TODO: Implement file download and open
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: msg['senderId'] == currentUser!.uid ? Colors.teal[400] : Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.attach_file),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg['fileName'],
                      style: TextStyle(
                        color: msg['senderId'] == currentUser!.uid ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      '${(msg['fileSize'] as int) ~/ 1024} KB',
                      style: TextStyle(
                        fontSize: 12,
                        color: msg['senderId'] == currentUser!.uid ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: msg['senderId'] == currentUser!.uid ? Colors.teal[400] : Colors.grey[300],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            msg['text'] ?? '',
            style: TextStyle(
              color: msg['senderId'] == currentUser!.uid ? Colors.white : Colors.black,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.teal[200],
              child: Text(
                widget.counselorName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.counselorName,
                  style: const TextStyle(fontSize: 16),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.counselorId)
                      .collection('status')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final status = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                    return Text(
                      status['isOnline'] ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: status['isOnline'] ? Colors.green : Colors.grey,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScheduleCallScreen(
                    counselorId: widget.counselorId,
                    counselorName: widget.counselorName,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.video_call),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallScreen(
                    roomCode: '${currentUser!.uid}_${widget.counselorId}',
                    userName: currentUser!.displayName ?? 'User',
                    isAudioOnly: false,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallScreen(
                    roomCode: '${currentUser!.uid}_${widget.counselorId}',
                    userName: currentUser!.displayName ?? 'User',
                    isAudioOnly: true,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return (data['senderId'] == currentUser!.uid &&
                              data['receiverId'] == widget.counselorId) ||
                          (data['senderId'] == widget.counselorId &&
                              data['receiverId'] == currentUser!.uid);
                    }).toList();

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index].data() as Map<String, dynamic>;
                        final isMe = msg['senderId'] == currentUser!.uid;
                        final timestamp = msg['timestamp'] as Timestamp?;
                        final showDate = index == messages.length - 1 ||
                            _formatTimestamp((messages[index + 1].data() as Map<String, dynamic>)['timestamp']) !=
                                _formatTimestamp(timestamp);

                        return Column(
                          children: [
                            if (showDate)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  _formatTimestamp(timestamp),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            Container(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: Row(
                                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (!isMe) ...[
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.teal[200],
                                      child: Text(
                                        widget.counselorName.substring(0, 1).toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: _buildMessageContent(msg),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      msg['isRead'] ?? false ? Icons.done_all : Icons.done,
                                      size: 16,
                                      color: msg['isRead'] ?? false ? Colors.blue : Colors.grey,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: _isUploading ? null : _pickAndUploadFile,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: "Type your message...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onChanged: (text) {
                          setState(() {
                            _isTyping = text.isNotEmpty;
                          });
                        },
                      ),
                    ),
                    if (_isTyping)
                      IconButton(
                        icon: const Icon(Icons.send),
                        color: Colors.teal,
                        onPressed: _sendMessage,
                      )
                    else
                      VoiceMessageRecorder(
                        receiverId: widget.counselorId,
                        onMessageSent: (audioUrl) {
                          // The message is already added to Firestore in the VoiceMessageRecorder
                          _scrollToBottom();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioService.dispose();
    super.dispose();
  }
}
