package se.alster.haphap

import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import kotlin.math.*
import kotlin.io.print

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
  //private var 

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
      "stop" -> {
        vibrator.cancel()
      }
      "runRampUp" -> {
        var rampCount = 60
        var fullCount = 600
        var amps = intArrayOf()
        var delays = longArrayOf()
        for (index in 0..fullCount) {
          var percentOfRamp: Double = min(1.0,index.toDouble() / rampCount.toDouble())
          var invertedPercent: Double = 1.0 - percentOfRamp
          var delay: Long = (70.0 * invertedPercent + 25.0).toLong()
          if (index % 2 == 0) {
            amps += (percentOfRamp * 128).toInt() //255 is max
          } else {
            amps += 0
          }
          
          delays += delay
        }

        //val timings: LongArray = longArrayOf(50, 50, 50, 50, 50, 100, 350, 25, 25, 25, 25, 200)
        //val amplitudes: IntArray = intArrayOf(33, 51, 75, 113, 170, 255, 0, 38, 62, 100, 160, 255)
        val repeatIndex = -1 // Do not repeat.

        vibrator.vibrate(VibrationEffect.createWaveform(delays, amps, repeatIndex))
      }
      "prepare" -> {
        // 
      }
      "runRelease" -> {
        val args = call.arguments as Map<String, Double>
        println(args)
        val power: Double = args["power"]!!

        val durationInMilliSeconds = 3000
        val timeStep: Long = 50
        val delta: Double = 1.0 / timeStep.toDouble()
        val fullCount: Int = (durationInMilliSeconds / timeStep).toInt()
        var amps = intArrayOf()
        var delays = longArrayOf()
        var currentValue: Double = 1.0
        val targetValue: Double = 0.0
        for (index in 0..fullCount) {
          var percentOfRamp: Double = min(1.0,index.toDouble() / fullCount.toDouble())
          var invertedPercent: Double = 1.0 - percentOfRamp
          currentValue += (targetValue - currentValue) * delta
          var x = 0.0 + currentValue * PI * 2 * 4.0
          var sine = (sin(x) * 0.4 + 0.6) * (1.0 - percentOfRamp)
          var delay: Long = timeStep// (70.0 * invertedPercent + 25.0).toLong()
          amps += (sine * 255).toInt()
          
          delays += delay
        }

        // cut of a portion from the arrays based on power
        val indexToCut: Int = ((1.0 - power) * fullCount.toDouble()).toInt()
        val newAmps = amps.drop(indexToCut).toIntArray()
        val newDelays = delays.drop(indexToCut).toLongArray()

        //val timings: LongArray = longArrayOf(50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50)
        //val amplitudes: IntArray = intArrayOf(255, 51, 220, 80, 170, 255, 0, 38, 62, 100, 70, 38)
        val repeatIndex = -1 // Do not repeat.

        vibrator.vibrate(VibrationEffect.createWaveform(newDelays, newAmps, repeatIndex))
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
