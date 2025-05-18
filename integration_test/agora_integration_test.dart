import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../test/agora_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late RtcEngine agoraEngine;
  bool engineInitialized = false;
  bool joinedChannel = false;

  setUp(() async {
    try {
      // Request permissions
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();
      
      print('Camera permission status: $cameraStatus');
      print('Microphone permission status: $micStatus');
      
      if (cameraStatus != PermissionStatus.granted || micStatus != PermissionStatus.granted) {
        throw Exception('Required permissions not granted');
      }
    } catch (e) {
      print('Error in setUp: $e');
      rethrow;
    }
  });

  tearDown(() async {
    try {
      if (joinedChannel) {
        print('Leaving channel...');
        await agoraEngine.leaveChannel();
        joinedChannel = false;
      }
      if (engineInitialized) {
        print('Releasing engine...');
        await agoraEngine.release();
        engineInitialized = false;
      }
    } catch (e) {
      print('Error in tearDown: $e');
    }
  });

  testWidgets('Full Agora integration test', (WidgetTester tester) async {
    try {
      print('Starting Agora integration test...');
      
      // Step 1: Create and initialize Agora engine
      print('Creating RTC engine...');
      agoraEngine = createAgoraRtcEngine();
      
      print('Initializing engine with App ID: ${AgoraConfig.appId}');
      await agoraEngine.initialize(RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));
      engineInitialized = true;
      print('Engine initialized successfully');

      // Step 2: Set event handlers
      bool remoteUserJoined = false;
      bool remoteUserLeft = false;
      bool localUserJoined = false;
      String? errorMessage;

      print('Setting up event handlers...');
      agoraEngine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print('Local user joined channel: ${connection.channelId}');
          localUserJoined = true;
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print('Remote user joined: $remoteUid');
          remoteUserJoined = true;
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          print('Remote user left: $remoteUid');
          remoteUserLeft = true;
        },
        onError: (ErrorCodeType err, String msg) {
          print('Agora error: $err - $msg');
          errorMessage = msg;
        },
      ));

      // Step 3: Enable video
      print('Enabling video...');
      await agoraEngine.enableVideo();
      await agoraEngine.startPreview();
      print('Video enabled and preview started');

      // Step 4: Set video encoder configuration
      print('Setting video encoder configuration...');
      await agoraEngine.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 640, height: 360),
          frameRate: 15,
          bitrate: 800,
        ),
      );

      // Step 5: Join channel
      print('Joining channel: ${AgoraConfig.testChannel}');
      await agoraEngine.joinChannel(
        token: AgoraConfig.testToken,
        channelId: AgoraConfig.testChannel,
        uid: AgoraConfig.uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      joinedChannel = true;
      print('Successfully joined channel');

      // Wait for local user to join with timeout
      print('Waiting for local user to join...');
      int attempts = 0;
      const maxAttempts = 10;
      while (!localUserJoined && attempts < maxAttempts) {
        await tester.pump(const Duration(seconds: 1));
        attempts++;
        print('Waiting for local user to join... Attempt $attempts/$maxAttempts');
      }

      if (!localUserJoined) {
        throw Exception('Failed to join channel after $maxAttempts attempts. Error: $errorMessage');
      }
      print('Local user joined successfully');

      // Test media controls
      print('Testing media controls...');
      await tester.pump(const Duration(seconds: 2));

      // Test muting audio
      print('Testing audio mute...');
      await agoraEngine.muteLocalAudioStream(true);
      await tester.pump(const Duration(seconds: 1));
      await agoraEngine.muteLocalAudioStream(false);
      print('Audio mute test completed');

      // Test disabling video
      print('Testing video disable...');
      await agoraEngine.muteLocalVideoStream(true);
      await tester.pump(const Duration(seconds: 1));
      await agoraEngine.muteLocalVideoStream(false);
      print('Video disable test completed');

      // Test switching camera
      print('Testing camera switch...');
      await agoraEngine.switchCamera();
      await tester.pump(const Duration(seconds: 1));
      print('Camera switch test completed');

      print('All tests completed successfully');
    } catch (e, stackTrace) {
      print('Error during test: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  });
} 