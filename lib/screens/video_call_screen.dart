import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../services/agora_service.dart';

class VideoCallScreen extends StatefulWidget {
  final bool isHost;
  final AgoraService? agoraService;

  const VideoCallScreen({
    Key? key,
    required this.isHost,
    this.agoraService,
  }) : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final AgoraService _agoraService;
  bool _isLocalVideoEnabled = true;
  bool _isLocalAudioEnabled = true;
  bool _isRemoteUserJoined = false;

  @override
  void initState() {
    super.initState();
    _agoraService = widget.agoraService ?? AgoraService();
    _initializeAgora();
  }

  Future<void> _initializeAgora() async {
    await _agoraService.initialize();
    
    _agoraService.onUserJoined = (uid) {
      setState(() {
        _isRemoteUserJoined = true;
      });
    };
    
    _agoraService.onUserOffline = (uid) {
      setState(() {
        _isRemoteUserJoined = false;
      });
    };

    await _agoraService.joinDefaultChannel(isHost: widget.isHost);
  }

  @override
  void dispose() {
    _agoraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video
          Center(
            child: _isRemoteUserJoined
                ? AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _agoraService.engine!,
                      canvas: VideoCanvas(uid: _agoraService.remoteUid),
                      connection: RtcConnection(channelId: _agoraService.defaultChannelName),
                    ),
                  )
                : const Center(
                    child: Text(
                      'Waiting for remote user to join...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
          ),
          
          // Local video
          Align(
            alignment: Alignment.topRight,
            child: Container(
              width: 100,
              height: 150,
              margin: const EdgeInsets.all(16),
              child: AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: _agoraService.engine!,
                  canvas: const VideoCanvas(uid: 0),
                ),
              ),
            ),
          ),
          
          // Controls
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: _isLocalAudioEnabled ? Icons.mic : Icons.mic_off,
                    onPressed: () {
                      setState(() {
                        _isLocalAudioEnabled = !_isLocalAudioEnabled;
                        _agoraService.toggleLocalAudio(_isLocalAudioEnabled);
                      });
                    },
                  ),
                  _buildControlButton(
                    icon: Icons.call_end,
                    backgroundColor: Colors.red,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildControlButton(
                    icon: _isLocalVideoEnabled ? Icons.videocam : Icons.videocam_off,
                    onPressed: () {
                      setState(() {
                        _isLocalVideoEnabled = !_isLocalVideoEnabled;
                        _agoraService.toggleLocalVideo(_isLocalVideoEnabled);
                      });
                    },
                  ),
                  _buildControlButton(
                    icon: Icons.switch_camera,
                    onPressed: () {
                      _agoraService.switchCamera();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color backgroundColor = Colors.white,
  }) {
    return RawMaterialButton(
      onPressed: onPressed,
      shape: const CircleBorder(),
      padding: const EdgeInsets.all(12),
      fillColor: backgroundColor,
      child: Icon(
        icon,
        color: backgroundColor == Colors.white ? Colors.black : Colors.white,
        size: 24,
      ),
    );
  }
} 