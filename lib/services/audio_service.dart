import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final _storage = FirebaseStorage.instance;
  String? _recordingPath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<bool> startRecording() async {
    try {
      if (await Permission.microphone.request().isGranted) {
        final directory = await getTemporaryDirectory();
        _recordingPath = '${directory.path}/audio_message_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
          path: _recordingPath!,
        );
        _isRecording = true;
        return true;
      }
      return false;
    } catch (e) {
      print('Error starting recording: $e');
      return false;
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _isRecording = false;
      return path ?? _recordingPath;
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    }
  }

  Future<String> uploadVoiceMessage(String filePath, String receiverId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final fileName = 'voice_messages/${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final file = File(filePath);
      
      // Upload to Firebase Storage
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      // Add message to Firestore
      await FirebaseFirestore.instance.collection('chats').add({
        'type': 'voice',
        'audioUrl': downloadUrl,
        'senderId': currentUser.uid,
        'receiverId': receiverId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Delete local file
      await file.delete();

      return downloadUrl;
    } catch (e) {
      print('Error uploading voice message: $e');
      rethrow;
    }
  }

  Future<String?> uploadAudio(String filePath) async {
    try {
      final file = File(filePath);
      final fileName = 'audio_messages/${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = _storage.ref().child(fileName);
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await file.delete();
      return url;
    } catch (e) {
      print('Error uploading audio: $e');
      return null;
    }
  }

  Future<void> initializePlayer(String audioUrl) async {
    await _audioPlayer.setSourceUrl(audioUrl);
  }

  Future<Duration?> getDuration() async {
    return _audioPlayer.getDuration();
  }

  Future<void> play() async {
    await _audioPlayer.resume();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> dispose() async {
    try {
      await _audioRecorder.dispose();
      await _audioPlayer.dispose();
    } catch (e) {
      print('Error disposing audio service: $e');
    }
  }
} 