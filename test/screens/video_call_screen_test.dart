import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:stressbuster/screens/video_call_screen.dart';
import 'package:stressbuster/services/agora_service.dart';
import 'video_call_screen_test.mocks.dart';

class MockRtcEngine extends Mock implements RtcEngine {}

@GenerateMocks([AgoraService])

void main() {
  late MockAgoraService mockAgoraService;
  late MockRtcEngine mockRtcEngine;

  setUp(() {
    mockAgoraService = MockAgoraService();
    mockRtcEngine = MockRtcEngine();
    when(mockAgoraService.engine).thenReturn(mockRtcEngine);
    when(mockAgoraService.defaultChannelName).thenReturn('test_channel');
    when(mockAgoraService.remoteUid).thenReturn(1);
  });

  group('VideoCallScreen Tests', () {
    testWidgets('should initialize Agora service on init',
        (WidgetTester tester) async {
      // Arrange
      when(mockAgoraService.initialize()).thenAnswer((_) async => null);
      when(mockAgoraService.joinDefaultChannel(isHost: true))
          .thenAnswer((_) async => null);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: VideoCallScreen(isHost: true, agoraService: mockAgoraService),
        ),
      );

      // Assert
      verify(mockAgoraService.initialize()).called(1);
      verify(mockAgoraService.joinDefaultChannel(isHost: true)).called(1);
    });

    testWidgets('should toggle local video when video button is pressed',
        (WidgetTester tester) async {
      // Arrange
      when(mockAgoraService.initialize()).thenAnswer((_) async => null);
      when(mockAgoraService.joinDefaultChannel(isHost: true))
          .thenAnswer((_) async => null);
      when(mockAgoraService.toggleLocalVideo(any))
          .thenAnswer((_) async => null);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: VideoCallScreen(isHost: true, agoraService: mockAgoraService),
        ),
      );

      // Find and tap the video toggle button
      final videoButton = find.byIcon(Icons.videocam);
      await tester.tap(videoButton);
      await tester.pump();

      // Assert
      verify(mockAgoraService.toggleLocalVideo(false)).called(1);
    });

    testWidgets('should toggle local audio when mic button is pressed',
        (WidgetTester tester) async {
      // Arrange
      when(mockAgoraService.initialize()).thenAnswer((_) async => null);
      when(mockAgoraService.joinDefaultChannel(isHost: true))
          .thenAnswer((_) async => null);
      when(mockAgoraService.toggleLocalAudio(any))
          .thenAnswer((_) async => null);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: VideoCallScreen(isHost: true, agoraService: mockAgoraService),
        ),
      );

      // Find and tap the mic toggle button
      final micButton = find.byIcon(Icons.mic);
      await tester.tap(micButton);
      await tester.pump();

      // Assert
      verify(mockAgoraService.toggleLocalAudio(false)).called(1);
    });

    testWidgets('should switch camera when switch camera button is pressed',
        (WidgetTester tester) async {
      // Arrange
      when(mockAgoraService.initialize()).thenAnswer((_) async => null);
      when(mockAgoraService.joinDefaultChannel(isHost: true))
          .thenAnswer((_) async => null);
      when(mockAgoraService.switchCamera())
          .thenAnswer((_) async => null);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: VideoCallScreen(isHost: true, agoraService: mockAgoraService),
        ),
      );

      // Find and tap the switch camera button
      final switchCameraButton = find.byIcon(Icons.switch_camera);
      await tester.tap(switchCameraButton);
      await tester.pump();

      // Assert
      verify(mockAgoraService.switchCamera()).called(1);
    });

    testWidgets('should show waiting message when no remote user is joined',
        (WidgetTester tester) async {
      // Arrange
      when(mockAgoraService.initialize()).thenAnswer((_) async => null);
      when(mockAgoraService.joinDefaultChannel(isHost: true))
          .thenAnswer((_) async => null);
      when(mockAgoraService.remoteUid).thenReturn(null);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: VideoCallScreen(isHost: true, agoraService: mockAgoraService),
        ),
      );

      // Assert
      expect(find.text('Waiting for remote user to join...'), findsOneWidget);
    });

    testWidgets('should end call when end call button is pressed',
        (WidgetTester tester) async {
      // Arrange
      when(mockAgoraService.initialize()).thenAnswer((_) async => null);
      when(mockAgoraService.joinDefaultChannel(isHost: true))
          .thenAnswer((_) async => null);
      when(mockAgoraService.dispose()).thenAnswer((_) async => null);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => VideoCallScreen(isHost: true, agoraService: mockAgoraService),
          ),
        ),
      );

      // Find and tap the end call button
      final endCallButton = find.byIcon(Icons.call_end);
      await tester.tap(endCallButton);
      await tester.pumpAndSettle();

      // Assert: The widget should be popped (not found in the tree)
      expect(find.byType(VideoCallScreen), findsNothing);
      // The dispose method should be called when the widget is removed
      verify(mockAgoraService.dispose()).called(1);
    });
  });
} 