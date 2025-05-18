import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:stressbuster/services/cashfree_service.dart';

@GenerateMocks([http.Client, CFPaymentGatewayService])
import 'cashfree_service_test.mocks.dart';

void main() {
  late MockClient mockHttpClient;
  late MockCFPaymentGatewayService mockCFPaymentGatewayService;
  late CashfreeService cashfreeService;

  setUp(() {
    mockHttpClient = MockClient();
    mockCFPaymentGatewayService = MockCFPaymentGatewayService();
    cashfreeService = CashfreeService(
      httpClient: mockHttpClient,
      cfPaymentGatewayService: mockCFPaymentGatewayService,
    );
  });

  group('CashfreeService HTTP Tests', () {
    test('createOrder - success', () async {
      // Arrange
      final orderId = 'test_order_123';
      final amount = 100.0;
      final customerId = 'test_customer_123';
      final customerEmail = 'test@example.com';
      final customerPhone = '1234567890';
      final customerName = 'Test User';

      final expectedResponse = {
        'order_id': orderId,
        'order_status': 'ACTIVE',
        'payment_session_id': 'test_session_123',
        'order_amount': amount,
        'order_currency': 'INR',
        'customer_details': {
          'customer_id': customerId,
          'customer_email': customerEmail,
          'customer_phone': customerPhone,
          'customer_name': customerName,
        },
      };

      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode(expectedResponse),
        200,
      ));

      // Act
      final result = await cashfreeService.createOrder(
        orderId: orderId,
        amount: amount,
        customerId: customerId,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
        customerName: customerName,
      );

      // Assert
      expect(result, equals(expectedResponse));
      verify(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).called(1);
    });

    test('createOrder - network error', () async {
      // Arrange
      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenThrow(Exception('Network error'));

      // Act & Assert
      expect(
        () => cashfreeService.createOrder(
          orderId: 'test_order_123',
          amount: 100.0,
          customerId: 'test_customer_123',
          customerEmail: 'test@example.com',
          customerPhone: '1234567890',
          customerName: 'Test User',
        ),
        throwsA(isA<CashfreeException>()),
      );
    });

    test('createOrder - invalid response format', () async {
      // Arrange
      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        'invalid json',
        200,
      ));

      // Act & Assert
      expect(
        () => cashfreeService.createOrder(
          orderId: 'test_order_123',
          amount: 100.0,
          customerId: 'test_customer_123',
          customerEmail: 'test@example.com',
          customerPhone: '1234567890',
          customerName: 'Test User',
        ),
        throwsA(isA<CashfreeException>()),
      );
    });

    test('createPaymentSession - success', () async {
      // Arrange
      final orderId = 'test_order_123';
      final expectedSessionId = 'test_session_123';

      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode({'payment_session_id': expectedSessionId}),
        200,
      ));

      // Act
      final result = await cashfreeService.createPaymentSession(
        orderId: orderId,
      );

      // Assert
      expect(result, equals(expectedSessionId));
      verify(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).called(1);
    });

    test('createPaymentSession - session not found', () async {
      // Arrange
      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode({'error': 'Session not found'}),
        404,
      ));

      // Act & Assert
      expect(
        () => cashfreeService.createPaymentSession(
          orderId: 'test_order_123',
        ),
        throwsA(isA<CashfreeException>()),
      );
    });

    test('verifyPaymentStatus - success', () async {
      // Arrange
      final orderId = 'test_order_123';
      final expectedResponse = {
        'order_id': orderId,
        'order_status': 'PAID',
        'payment_details': {
          'payment_method': 'UPI',
          'payment_amount': 100.0,
        },
      };

      when(mockHttpClient.get(
        any,
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode(expectedResponse),
        200,
      ));

      // Act
      final result = await cashfreeService.verifyPaymentStatus(orderId);

      // Assert
      expect(result, equals(expectedResponse));
      verify(mockHttpClient.get(
        any,
        headers: anyNamed('headers'),
      )).called(1);
    });

    test('verifyPaymentStatus - order not found', () async {
      // Arrange
      when(mockHttpClient.get(
        any,
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode({'error': 'Order not found'}),
        404,
      ));

      // Act & Assert
      expect(
        () => cashfreeService.verifyPaymentStatus('non_existent_order'),
        throwsA(isA<CashfreeException>()),
      );
    });

    test('verifyPaymentStatus - server error', () async {
      // Arrange
      when(mockHttpClient.get(
        any,
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode({'error': 'Internal server error'}),
        500,
      ));

      // Act & Assert
      expect(
        () => cashfreeService.verifyPaymentStatus('test_order_123'),
        throwsA(isA<CashfreeException>()),
      );
    });

    test('setPaymentCallbacks - success', () {
      // Arrange
      void onSuccess(String orderId) {}
      void onError(CFErrorResponse error, String orderId) {}

      // Act
      cashfreeService.setPaymentCallbacks(
        onSuccess: onSuccess,
        onError: onError,
      );

      // Assert
      verify(mockCFPaymentGatewayService.setCallback(onSuccess, onError)).called(1);
    });

    test('doPayment - success', () async {
      // Arrange
      final orderId = 'test_order_123';
      final paymentSessionId = 'test_session_123';
      final payment = CFDropCheckoutPayment(
        sessionId: paymentSessionId,
        orderId: orderId,
        environment: CFEnvironment.SANDBOX,
      );

      when(mockCFPaymentGatewayService.doPayment(any)).thenAnswer((_) async => null);

      // Act
      await cashfreeService.doPayment(orderId, paymentSessionId);

      // Assert
      verify(mockCFPaymentGatewayService.doPayment(any)).called(1);
    });
  });
} 