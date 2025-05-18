import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraService {
  static const String _appId = '1bd37c6241ca42dbb80b1526e8d59e54';
  static const String _appCertificate = '637f68394c164b5f8b9731255e70b3d9';
  static const String _defaultToken = '007eJxTYLjial/OMP95JWvSWtF80Zu2dZf7Z5/MvsE864uRS8tUht0KDIZJKcbmyWZGJobJiSZGKUlJFgZJhqZGZqkWKaaWqaYmT4sUMxoCGRlYVixmYmSAQBCfh6G4pCi1uDiptLgktYiBAQAUlyIK';
  static const String _defaultChannelName = 'stressbuster_channel';
  static const int _defaultUid = 0;
  
  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isInCall = false;
  int? _localUid;
  int? _remoteUid;
  
  // Callbacks
  Function(int)? onUserJoined;
  Function(int)? onUserOffline;
  Function(int)? onFirstLocalVideoFrame;
  Function(int)? onFirstRemoteVideoFrame;
  Function(int)? onError;
  
  // Getters
  String get defaultChannelName => _defaultChannelName;
  int get defaultUid => _defaultUid;
  
  // Initialize Agora Engine
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Request permissions
      await [Permission.camera, Permission.microphone].request();
      
      // Create RTC Engine
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: _appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));
      
      // Enable video and audio
      await _engine!.enableVideo();
      await _engine!.enableAudio();
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      
      // Set event handlers
      _engine!.registerEventHandler(RtcEngineEventHandler(
        onError: (err, msg) {
          debugPrint('Agora Error: $err, $msg');
          onError?.call(err.index);
        },
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('Local user joined channel');
          _isInCall = true;
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('Remote user joined: $remoteUid');
          _remoteUid = remoteUid;
          onUserJoined?.call(remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('Remote user left: $remoteUid');
          _remoteUid = null;
          onUserOffline?.call(remoteUid);
        },
        onFirstLocalVideoFrame: (connection, width, height, elapsed) {
          debugPrint('First local video frame');
          onFirstLocalVideoFrame?.call(elapsed);
        },
        onFirstRemoteVideoFrame: (connection, remoteUid, width, height, elapsed) {
          debugPrint('First remote video frame');
          onFirstRemoteVideoFrame?.call(elapsed);
        },
      ));
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing Agora: $e');
      rethrow;
    }
  }
  
  // Join a channel with default token
  Future<void> joinDefaultChannel({
    required bool isHost,
  }) async {
    await joinChannel(
      channelName: _defaultChannelName,
      token: _defaultToken,
      uid: 0,
      role: isHost 
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );
  }
  
  // Join a channel with custom token
  Future<void> joinChannel({
    required String channelName,
    required String token,
    required int uid,
    required ClientRoleType role,
  }) async {
    if (!_isInitialized) await initialize();
    
    _localUid = uid;
    await _engine!.setClientRole(role: role);
    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );
  }
  
  // Leave the channel
  Future<void> leaveChannel() async {
    if (!_isInitialized) return;
    
    try {
      await _engine!.leaveChannel();
      _isInCall = false;
      _localUid = null;
      _remoteUid = null;
    } catch (e) {
      debugPrint('Error leaving channel: $e');
    }
  }
  
  // Toggle local video
  Future<void> toggleLocalVideo(bool enabled) async {
    await _engine?.muteLocalVideoStream(!enabled);
  }
  
  // Toggle local audio
  Future<void> toggleLocalAudio(bool enabled) async {
    await _engine?.muteLocalAudioStream(!enabled);
  }
  
  // Switch camera
  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }
  
  // Dispose resources
  Future<void> dispose() async {
    if (!_isInitialized) return;
    
    try {
      await leaveChannel();
      await _engine!.release();
      _isInitialized = false;
    } catch (e) {
      debugPrint('Error disposing Agora: $e');
    }
  }
  
  // Get current call state
  bool get isInCall => _isInCall;
  int? get localUid => _localUid;
  int? get remoteUid => _remoteUid;
  
  RtcEngine? get engine => _engine;
} 