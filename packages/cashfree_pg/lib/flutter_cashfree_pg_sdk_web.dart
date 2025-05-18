// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter

/**
    Predefining a structure to send back response in json string
    onSuccess
    {
    "status": "success",
    "data": {
    "order_id": ""
    }
    }

    onFailure
    {
    "status": "failed",
    "data": {
    "order_id":"",
    "message":"",
    "code":"",
    "type":"",
    "":""
    }
    }

    onException
    {
    "status": "exception",
    "data": {
    "message": ""
    }
    }
 */

@JS('CFFlutter')
library CFFlutter;

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html show window;
import 'dart:html';
import 'dart:js';

import 'package:flutter/services.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'package:js/js.dart';

import 'api/cferrorresponse/cferrorresponse.dart';


external Cashfree get cashfree;

@JS()
class Cashfree {
  external Cashfree(String paymentSessionId);
  external void drop(Element element, CFConfig cfConfig);
  external void redirect();
}

@JS()
@anonymous
class CFConfig {
  external List<String> get components;
  external String get orderToken;
  external String get pluginName;
  external Map<String, String> get style;
  external Function(dynamic) get onSuccess;
  external Function(dynamic) get onFailure;

  external factory CFConfig({List<String> components, String orderToken, String pluginName, Map<String, String> style, Function onSuccess, Function onFailure});
}

/// A web implementation of the FlutterCashfreePgSdkPlatform of the FlutterCashfreePgSdk plugin.
class FlutterCashfreePgSdkWeb {
  /// Constructs a FlutterCashfreePgSdkWeb
  FlutterCashfreePgSdkWeb();

  void Function(String)? _verifyPayment;
  void Function(CFErrorResponse, String)? _onError;

  DivElement? _outerDiv;
  String? _order_id;

  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'flutter_cashfree_pg_sdk',
      const StandardMethodCodec(),
      registrar,
    );

    final pluginInstance = FlutterCashfreePgSdkWeb();
    channel.setMethodCallHandler(pluginInstance.handleMethodCall);
  }

  /// Handles method calls over the MethodChannel of this plugin.
  /// Note: Check the "federated" architecture for a new way of doing this:
  /// https://flutter.dev/go/federated-plugins
  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'doPayment':
        var arguments = call.arguments as dynamic;
        doPayment(arguments);
        break;
      case 'doWebPayment':
        var arguments = call.arguments as dynamic;
        doWebPayment(arguments);
        break;
      case "response":
        break;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'flutter_cashfree_pg_sdk for web doesn\'t implement \'${call.method}\'',
        );
    }
  }


  void onSuccess(String data) {
    var jsonObject = json.decode(data) as Map<String, dynamic>;
    var order = jsonObject["order"];
    var orderId = order["orderId"] as String;
    if(_verifyPayment != null) {
      _verifyPayment!(orderId);
      _outerDiv?.remove();
    }
  }

  void onFailure(String data) {
    var jsonObject = json.decode(data) as Map<String, dynamic>;
    var order = jsonObject["order"];
    var orderId = order["orderId"] as dynamic ?? "";
    var message = order["errorText"] as String? ?? "";
    var transaction = jsonObject["transaction"] as dynamic;
    if(transaction != null) {
      message = transaction["txMsg"] as String;
      if(_onError != null) {
        var errorResponse = CFErrorResponse("FAILED", message, "invalid_request", "invalid request");
        _onError!(errorResponse, orderId);
        _outerDiv?.remove();
      }
    } else {
      if((message.toLowerCase() == "order is no longer active") || (message.toLowerCase() == "token is not present")) {
        if(_onError != null) {
          var errorResponse = CFErrorResponse("FAILED", message, "invalid_request", "invalid request");
          _onError!(errorResponse, orderId.toString());
          _outerDiv?.remove();
        }
      } else {
        _showToast(message);
      }
    }
  }

  void _showToast(String message) {

    DivElement toast = DivElement();
    toast.text = message;
    toast.style.visibility = "visible";
    toast.style.minWidth = "200px";
    toast.style.position = "fixed";
    toast.style.left = "50%";
    toast.style.transform = "translate(-50%)";
    toast.style.top = "7.5%";
    toast.style.background = "red";
    toast.style.color = "white";
    toast.style.textAlign = "center";
    toast.style.verticalAlign = "middle";
    toast.style.lineHeight = "27px";
    toast.style.fontSize = "14px";
    toast.style.borderRadius = "5px";
    toast.style.padding = "8px";
    _outerDiv?.append(toast);

    Timer.periodic(const Duration(seconds: 5), (timer) {
      toast.remove();
      timer.cancel();
    });
  }

  void _userCancelledTransaction() {
    if(_onError != null) {
      var errorResponse = CFErrorResponse(
          "FAILED", "Transaction cancelled by user", "invalid_request",
          "invalid request");
      _onError!(errorResponse, _order_id ?? "order_id_not_found");
      _outerDiv?.remove();
    }
  }

  /// WEB REDIRECTION
  void doWebPayment(dynamic arguments) {
    var window = html.window;
    var document = window.document;

    var session = arguments["session"] as dynamic;

    String environment = session["environment"] as String;
    String paymentSessionId = session["payment_session_id"] as String;

    var script = document.createElement("SCRIPT") as ScriptElement;
    if(environment == "SANDBOX") {
      script.src =
      "https://sdk.cashfree.com/js/flutter/2.0.0/cashfree.sandbox.js ";
    } else {
      script.src =
      "https://sdk.cashfree.com/js/flutter/2.0.0/cashfree.prod.js";
    }
    script.onLoad.first.then((value) {
      var c = Cashfree(paymentSessionId);
      c.redirect();
    });
    document.querySelector("body")?.children.add(script);
  }

  /// WEB
  void doPayment(dynamic arguments) async {
    try {
      var window = html.window;
      var document = window.document;

      // Handle payment cancellation
      window.onHashChange.first.then((value) {
        _userCancelledTransaction();
      });

      var session = arguments["session"] as dynamic;
      if (session == null || !session.containsKey("order_id") || !session.containsKey("payment_session_id")) {
        throw Exception('Invalid session data');
      }

      var orderId = session["order_id"] as String;
      _order_id = orderId;

      // Create payment UI container
      DivElement outerDiv = DivElement()
        ..id = "cf-outer-div"
        ..style.position = "fixed"
        ..style.width = "100%"
        ..style.height = "100%"
        ..style.top = "0"
        ..style.left = "0"
        ..style.background = "#6b6c7b80"
        ..style.zIndex = "9999";

      DivElement sdkDiv = DivElement()
        ..id = "cf-flutter-placeholder"
        ..style.position = "fixed"
        ..style.left = "50%"
        ..style.top = "50%"
        ..style.width = "400px"
        ..style.height = "100%"
        ..style.maxWidth = "100%"
        ..style.transform = "translate(-50%, -50%)"
        ..style.overflow = "auto";

      // Add close button
      DivElement closeButton = DivElement()
        ..text = "X"
        ..style.position = "fixed"
        ..style.right = "10px"
        ..style.top = "10px"
        ..style.fontSize = "24px"
        ..style.color = "#ff0000"
        ..onClick.listen((event) {
          _userCancelledTransaction();
        });

      sdkDiv.append(closeButton);
      outerDiv.append(sdkDiv);
      document.querySelector("body")?.children.add(outerDiv);
      _outerDiv = outerDiv;

      // Setup callbacks
      _onError = CFPaymentGatewayService.onError;
      _verifyPayment = CFPaymentGatewayService.verifyPayment;

      // Get configuration
      String environment = session["environment"] as String? ?? "PRODUCTION";
      String paymentSessionId = session["payment_session_id"] as String;

      var paymentComponents = arguments["paymentComponents"] as dynamic;
      var components = paymentComponents?["components"] as List<dynamic>? ?? [];
      List<String> componentsToSend = ["order-details"];

      // Map payment components
      for (var component in components) {
        if (component == "wallet") {
          componentsToSend.add("app");
        } else if (component == "emi") {
          componentsToSend.add("creditcardemi");
          componentsToSend.add("cardlessemi");
        } else {
          componentsToSend.add(component.toString());
        }
      }

      // Setup theme
      var theme = arguments["theme"] as dynamic? ?? {};
      String backgroundColor = theme["navigationBarBackgroundColor"] as String? ?? "#E34F26";
      String color = theme["navigationBarTextColor"] as String? ?? "#FFFFFF";
      String font = theme["primaryFont"] as String? ?? "Menlo";

      var style = {
        "backgroundColor": backgroundColor,
        "color": color,
        "fontFamily": font,
        "fontSize": "14px",
        "errorColor": "#ff0000",
        "theme": "light"
      };

      // Load Cashfree SDK
      var script = document.createElement("SCRIPT") as ScriptElement;
      script.src = environment == "SANDBOX"
          ? "https://sdk.cashfree.com/js/flutter/2.0.0/cashfree.sandbox.js"
          : "https://sdk.cashfree.com/js/flutter/2.0.0/cashfree.prod.js";

      script.onLoad.first.then((value) {
        try {
          var c = Cashfree(paymentSessionId);
          var element = document.getElementById("cf-flutter-placeholder");
          if (element == null) {
            throw Exception('Payment container not found');
          }

          var os = allowInterop(onSuccess);
          var of = allowInterop(onFailure);

          var cfConfig = CFConfig(
            components: componentsToSend,
            pluginName: "jflt-d-2.0.10-3.3.10",
            onFailure: of,
            onSuccess: os,
            style: style
          );

          c.drop(element, cfConfig);
        } catch (e) {
          _handleError('Error initializing payment: $e');
        }
      }).catchError((e) {
        _handleError('Error loading payment SDK: $e');
      });

      document.querySelector("body")?.children.add(script);
    } catch (e) {
      _handleError('Error setting up payment: $e');
    }
  }

  void _handleError(String message) {
    if (_onError != null) {
      _onError!(CFErrorResponse(
        'ERROR',
        message,
        'INITIALIZATION_ERROR',
        'SYSTEM_ERROR'
      ), _order_id ?? '');
    }
    _cleanup();
  }

  void _cleanup() {
    if (_outerDiv != null) {
      _outerDiv?.remove();
      _outerDiv = null;
    }
  }
}
