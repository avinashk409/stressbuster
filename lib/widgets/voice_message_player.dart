import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  const VoiceMessagePlayer({
    Key? key,
    required this.audioUrl,
    required this.isMe,
  }) : super(key: key);

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioService _audioService = AudioService();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    await _audioService.initializePlayer(widget.audioUrl);
    _duration = await _audioService.getDuration() ?? Duration.zero;
    setState(() {});
  }

  Future<void> _playPause() async {
    if (_isPlaying) {
      await _audioService.pause();
    } else {
      await _audioService.play();
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMe ? Theme.of(context).primaryColor : Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: widget.isMe ? Colors.white : Colors.black,
            ),
            onPressed: _playPause,
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_position),
            style: TextStyle(
              color: widget.isMe ? Colors.white : Colors.black,
            ),
          ),
          const Text(' / '),
          Text(
            _formatDuration(_duration),
            style: TextStyle(
              color: widget.isMe ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
} 