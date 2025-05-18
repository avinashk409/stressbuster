package io.agora.agora_rtc_engine;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class AgoraRtcEnginePlugin implements FlutterPlugin, MethodCallHandler {
  private MethodChannel channel;
  private FlutterPluginBinding flutterPluginBinding;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    flutterPluginBinding = binding;
    channel = new MethodChannel(binding.getBinaryMessenger(), "agora_rtc_engine");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    try {
      switch (call.method) {
        case "getPlatformVersion":
          result.success("Android " + android.os.Build.VERSION.RELEASE);
          break;
        case "create":
          String appId = call.argument("appId");
          if (appId == null || appId.isEmpty()) {
            result.error("INVALID_APP_ID", "App ID cannot be null or empty", null);
            return;
          }
          // Placeholder for create method implementation
          result.success(null);
          break;
        case "destroy":
          // Placeholder for destroy method implementation
          result.success(null);
          break;
        default:
          result.notImplemented();
      }
    } catch (Exception e) {
      result.error("ERROR", e.getMessage(), null);
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    flutterPluginBinding = null;
  }
} 