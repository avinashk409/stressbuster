import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../services/agora_service.dart';
import '../utils/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_rtc_engine/src/agora_rtc_engine_ex.dart';

class CallScreen extends StatefulWidget {
  final String roomCode;
  final String userName;
  final bool isAudioOnly;
  final dynamic permissionUtils;

  const CallScreen({
    Key? key,
    required this.roomCode,
    required this.userName,
    this.isAudioOnly = false,
    this.permissionUtils,
  }) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final AgoraService _agoraService = AgoraService();
  bool _muted = false;
  bool _cameraOff = false;
  bool _speakerOn = true;
  bool _isLoading = true;
  Timer? _callTimer;
  String _callDuration = '00:00';
  int _secondsElapsed = 0;
  bool _remoteUserJoined = false;
  String _remoteUserName = "Counselor";

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _agoraService.dispose();
    super.dispose();
  }

  Future<void> _initializeCall() async {
    // Request permissions
    if (context.mounted) {
      final permissionsGranted = widget.permissionUtils != null
          ? await widget.permissionUtils.requestCameraAndMicPermission(context)
          : await PermissionUtils.requestCameraAndMicPermission(context);
      if (!permissionsGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera and microphone permissions are required for video calls'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
          return;
        }
      }
    }

    setState(() {
      _isLoading = true;
      if (widget.isAudioOnly) {
        _cameraOff = true;
      }
    });

    // Initialize Agora
    await _agoraService.initialize();
    
    _agoraService.onUserJoined = (uid) {
      setState(() {
        _remoteUserJoined = true;
        _isLoading = false;
      });
    };
    
    _agoraService.onUserOffline = (uid) {
      setState(() {
        _remoteUserJoined = false;
      });
    };

    // Join channel
    await _agoraService.joinDefaultChannel(
      isHost: true, // Assuming the caller is always the host
    );
    
    // Start call timer
    _startCallTimer();
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsElapsed++;
      final duration = Duration(seconds: _secondsElapsed);
      setState(() {
        _callDuration = _formatDuration(duration);
      });
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    }
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Connecting to call...'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildLoading(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video
          Center(
            child: _remoteUserJoined
                ? AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _agoraService.engine!,
                      canvas: VideoCanvas(uid: _agoraService.remoteUid),
                      connection: RtcConnection(channelId: AgoraService().defaultChannelName),
                    ),
                  )
                : _buildVideoDisplay(isLocal: true, cameraOff: _cameraOff),
          ),
          
          // Local video preview
          if (!widget.isAudioOnly)
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
          
          // Call info overlay
          Positioned(
            top: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _remoteUserJoined ? 'Connected' : 'Waiting for other participant...',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Text(
                      _callDuration,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
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
                    icon: _muted ? Icons.mic_off : Icons.mic,
                    onPressed: () {
                      setState(() {
                        _muted = !_muted;
                        _agoraService.toggleLocalAudio(!_muted);
                      });
                    },
                  ),
                  if (!widget.isAudioOnly)
                    _buildControlButton(
                      icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
                      onPressed: () {
                        setState(() {
                          _cameraOff = !_cameraOff;
                          _agoraService.toggleLocalVideo(!_cameraOff);
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
                    icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                    onPressed: () {
                      setState(() {
                        _speakerOn = !_speakerOn;
                        // TODO: Implement speaker toggle
                      });
                    },
                  ),
                  if (!widget.isAudioOnly)
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

  Widget _buildVideoDisplay({bool isLocal = true, bool cameraOff = false}) {
    final name = isLocal ? widget.userName : _remoteUserName;
    
    if (cameraOff) {
      return Container(
        color: Colors.blueGrey.shade900,
        child: Center(
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.blue.shade300,
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isLocal ? Alignment.topLeft : Alignment.bottomRight,
            end: isLocal ? Alignment.bottomRight : Alignment.topLeft,
            colors: isLocal
                ? [Colors.blue.shade800, Colors.blue.shade500]
                : [Colors.purple.shade800, Colors.purple.shade500],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Icon(
                    Icons.videocam,
                    size: 60,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Flexible(
                  child: Text(
                    isLocal ? 'Local Video' : 'Remote Video',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}
