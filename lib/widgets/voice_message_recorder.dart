import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class VoiceMessageRecorder extends StatefulWidget {
  final String receiverId;
  final Function(String) onMessageSent;

  const VoiceMessageRecorder({
    Key? key,
    required this.receiverId,
    required this.onMessageSent,
  }) : super(key: key);

  @override
  State<VoiceMessageRecorder> createState() => _VoiceMessageRecorderState();
}

class _VoiceMessageRecorderState extends State<VoiceMessageRecorder> {
  final AudioService _audioService = AudioService();
  bool _isRecording = false;
  String? _recordingPath;

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final success = await _audioService.startRecording();
    if (success) {
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioService.stopRecording();
    setState(() {
      _isRecording = false;
      _recordingPath = path;
    });

    if (path != null) {
      try {
        final downloadUrl = await _audioService.uploadVoiceMessage(
          path,
          widget.receiverId,
        );
        widget.onMessageSent(downloadUrl);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            _isRecording ? Icons.stop : Icons.mic,
            color: _isRecording ? Colors.red : Theme.of(context).primaryColor,
          ),
          onPressed: _isRecording ? _stopRecording : _startRecording,
        ),
        if (_isRecording)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Recording...',
              style: TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }
} 