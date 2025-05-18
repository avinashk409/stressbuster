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

  group('Network Condition Tests', () {
    testWidgets('Test reconnection after network loss', (WidgetTester tester) async {
      try {
        print('Starting network reconnection test...');
        agoraEngine = createAgoraRtcEngine();
        await agoraEngine.initialize(RtcEngineContext(
          appId: AgoraConfig.appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ));
        engineInitialized = true;

        bool connectionLost = false;
        bool reconnected = false;

        agoraEngine.registerEventHandler(RtcEngineEventHandler(
          onConnectionLost: (RtcConnection connection) {
            print('Connection lost');
            connectionLost = true;
          },
          onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
            if (state == ConnectionStateType.connectionStateConnected) {
              print('Reconnected to channel');
              reconnected = true;
            }
          },
        ));

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

        // Simulate network loss (you'll need to manually disable network)
        print('Please disable network connection now...');
        await tester.pump(const Duration(seconds: 10));

        // Re-enable network
        print('Please re-enable network connection now...');
        await tester.pump(const Duration(seconds: 20));

        expect(connectionLost, isTrue, reason: 'Connection loss not detected');
        expect(reconnected, isTrue, reason: 'Reconnection not successful');
      } catch (e) {
        print('Error in network test: $e');
        rethrow;
      }
    });
  });

  group('Error Handling Tests', () {
    testWidgets('Test invalid token handling', (WidgetTester tester) async {
      try {
        print('Starting invalid token test...');
        agoraEngine = createAgoraRtcEngine();
        await agoraEngine.initialize(RtcEngineContext(
          appId: AgoraConfig.appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ));
        engineInitialized = true;

        String? errorMessage;
        agoraEngine.registerEventHandler(RtcEngineEventHandler(
          onError: (ErrorCodeType err, String msg) {
            print('Agora error: $err - $msg');
            errorMessage = msg;
          },
        ));

        // Try to join with invalid token
        await agoraEngine.joinChannel(
          token: 'invalid_token',
          channelId: AgoraConfig.testChannel,
          uid: AgoraConfig.uid,
          options: const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          ),
        );
        joinedChannel = true;

        await tester.pump(const Duration(seconds: 5));
        expect(errorMessage, isNotNull, reason: 'No error message received for invalid token');
      } catch (e) {
        print('Error in invalid token test: $e');
        rethrow;
      }
    });
  });

  group('Performance Tests', () {
    testWidgets('Test rapid camera switching', (WidgetTester tester) async {
      try {
        print('Starting rapid camera switching test...');
        agoraEngine = createAgoraRtcEngine();
        await agoraEngine.initialize(RtcEngineContext(
          appId: AgoraConfig.appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ));
        engineInitialized = true;

        await agoraEngine.enableVideo();
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

        // Perform rapid camera switches
        for (int i = 0; i < 10; i++) {
          await agoraEngine.switchCamera();
          await tester.pump(const Duration(milliseconds: 500));
        }

        // Verify engine is still responsive
        await agoraEngine.muteLocalAudioStream(true);
        await tester.pump(const Duration(seconds: 1));
        await agoraEngine.muteLocalAudioStream(false);
      } catch (e) {
        print('Error in camera switching test: $e');
        rethrow;
      }
    });

    testWidgets('Test rapid audio/video toggling', (WidgetTester tester) async {
      try {
        print('Starting rapid audio/video toggle test...');
        agoraEngine = createAgoraRtcEngine();
        await agoraEngine.initialize(RtcEngineContext(
          appId: AgoraConfig.appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ));
        engineInitialized = true;

        await agoraEngine.enableVideo();
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

        // Rapidly toggle audio and video
        for (int i = 0; i < 10; i++) {
          await agoraEngine.muteLocalAudioStream(i % 2 == 0);
          await agoraEngine.muteLocalVideoStream(i % 2 == 0);
          await tester.pump(const Duration(milliseconds: 500));
        }

        // Verify final state
        await agoraEngine.muteLocalAudioStream(false);
        await agoraEngine.muteLocalVideoStream(false);
        await tester.pump(const Duration(seconds: 1));
      } catch (e) {
        print('Error in audio/video toggle test: $e');
        rethrow;
      }
    });
  });

  group('Resource Management Tests', () {
    testWidgets('Test multiple engine instances', (WidgetTester tester) async {
      try {
        print('Starting multiple engine instances test...');
        final engine1 = createAgoraRtcEngine();
        final engine2 = createAgoraRtcEngine();

        await engine1.initialize(RtcEngineContext(
          appId: AgoraConfig.appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ));

        await engine2.initialize(RtcEngineContext(
          appId: AgoraConfig.appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ));

        // Verify both engines are working
        await engine1.enableVideo();
        await engine2.enableVideo();

        // Clean up
        await engine1.release();
        await engine2.release();
      } catch (e) {
        print('Error in multiple engines test: $e');
        rethrow;
      }
    });

    testWidgets('Test memory usage during long session', (WidgetTester tester) async {
      try {
        print('Starting long session memory test...');
        agoraEngine = createAgoraRtcEngine();
        await agoraEngine.initialize(RtcEngineContext(
          appId: AgoraConfig.appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ));
        engineInitialized = true;

        await agoraEngine.enableVideo();
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

        // Simulate a long session with various operations
        for (int i = 0; i < 5; i++) {
          await agoraEngine.muteLocalAudioStream(i % 2 == 0);
          await agoraEngine.muteLocalVideoStream(i % 2 == 0);
          await agoraEngine.switchCamera();
          await tester.pump(const Duration(seconds: 2));
        }

        // Verify engine is still responsive
        await agoraEngine.muteLocalAudioStream(false);
        await agoraEngine.muteLocalVideoStream(false);
        await tester.pump(const Duration(seconds: 1));
      } catch (e) {
        print('Error in long session test: $e');
        rethrow;
      }
    });
  });
} 