package se.alster.haphap

import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** HaphapPlugin */
class HaphapPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var vibrator: Vibrator

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "haphap")
    channel.setMethodCallHandler(this)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      vibrator = flutterPluginBinding.applicationContext.getSystemService(Vibrator::class.java)
    }
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "canSupportsHaptic" -> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
          result.success(vibrator.hasVibrator())
        } else {
          result.success(false)
        }
      }
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "runRampUp" -> {
        val timings: LongArray = longArrayOf(50, 50, 50, 50, 50, 100, 350, 25, 25, 25, 25, 200)
        val amplitudes: IntArray = intArrayOf(33, 51, 75, 113, 170, 255, 0, 38, 62, 100, 160, 255)
        val repeatIndex = -1 // Do not repeat.

        vibrator.vibrate(VibrationEffect.createWaveform(timings, amplitudes, repeatIndex))
      }
      "prepare" -> {
        // TODO: try to read .ahap file & convert it to waveform
      }
      "runRelease" -> {
        val timings: LongArray = longArrayOf(50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50)
        val amplitudes: IntArray = intArrayOf(255, 51, 220, 80, 170, 255, 0, 38, 62, 100, 70, 38)
        val repeatIndex = -1 // Do not repeat.

        vibrator.vibrate(VibrationEffect.createWaveform(timings, amplitudes, repeatIndex))
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
