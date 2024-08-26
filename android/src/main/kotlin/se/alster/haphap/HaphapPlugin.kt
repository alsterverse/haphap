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
  private lateinit var sineAmps: IntArray
  private lateinit var sineDelays: LongArray
  private lateinit var escalatingAmps: IntArray
  private lateinit var escalatingDelays: LongArray
  private var releaseDurationInMilliSeconds: Int = 4000
  private var revolutions: Double = 4.0
  private var useExponentialCurve: Boolean = false
  private val timeStepInMilliSeconds = 50

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "haphap")
    channel.setMethodCallHandler(this)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      vibrator = flutterPluginBinding.applicationContext.getSystemService(Vibrator::class.java)
    }
    createPatterns()
  }

  private fun createPatterns() {
    val (sineAmps, sineDelays) = generateSineAmpsAndDelays()
    this.sineAmps = sineAmps
    this.sineDelays = sineDelays

    val (escalatingAmps, escalatingDelays) = generateEscalatingAmpsAndDelays()
    this.escalatingAmps = escalatingAmps
    this.escalatingDelays = escalatingDelays
  }

  private fun generateSineAmpsAndDelays(): Pair<IntArray, LongArray> {
    val delta: Double = 1.0 / timeStepInMilliSeconds.toDouble()
    val fullCount: Int = (releaseDurationInMilliSeconds / timeStepInMilliSeconds)
    var amps = intArrayOf()
    var delays = longArrayOf()
    var currentValue: Double = 1.0
    val targetValue: Double = 0.0
    for (index in 0..fullCount) {
      val percentOfRamp: Double = min(1.0,index.toDouble() / fullCount.toDouble())
      val invertedPercent: Double = 1.0 - percentOfRamp
      currentValue += (targetValue - currentValue) * delta
      val value = if(useExponentialCurve) currentValue else percentOfRamp
      val x = value * PI * 2 * revolutions
      val y = (cos(x) * 0.5 + 0.5) * invertedPercent
      
      amps += (y * 255).toInt()

      val delay: Long = timeStepInMilliSeconds.toLong()
      delays += delay
    }
    return Pair(amps, delays)
  }

  private fun generateEscalatingAmpsAndDelays(): Pair<IntArray, LongArray> {
    val rampCount = 60
    val fullCount = 600
    var amps = intArrayOf()
    var delays = longArrayOf()
    for (index in 0..fullCount) {
      val percentOfRamp: Double = min(1.0,index.toDouble() / rampCount.toDouble())
      val invertedPercent: Double = 1.0 - percentOfRamp
      val delay: Long = (70.0 * invertedPercent + 25.0).toLong()
      amps += if (index % 2 == 0) {
        (percentOfRamp * 100 + 28).toInt() //255 is max
      } else {
        0
      }

      delays += delay
    }
    return Pair(amps, delays)
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
        val repeatIndex = -1 // Do not repeat.
        vibrator.vibrate(VibrationEffect.createWaveform(escalatingDelays, escalatingAmps, repeatIndex))
      }
      "prepare" -> {
        // Need this or else it acts as unimplemented
      }
      "goToIdle" -> {
        // Need this or else it acts as unimplemented
      }
      "runRelease" -> {
        val args = call.arguments as Map<String, Double>
        println(args)
        val power: Double = args["power"]!!

        val fullCount: Int = (releaseDurationInMilliSeconds / timeStepInMilliSeconds).toInt()

        // cut of a portion from the arrays based on power
        val indexToCut: Int = ((1.0 - power) * fullCount.toDouble()).toInt()
        val newAmps = sineAmps.drop(indexToCut).toIntArray()
        val newDelays = sineDelays.drop(indexToCut).toLongArray()
        val repeatIndex = -1 // Do not repeat.

        vibrator.vibrate(VibrationEffect.createWaveform(newDelays, newAmps, repeatIndex))
      }
      "updateSettings" -> {
        val args = call.arguments as Map<String, Any>
        println(args)
        val releaseDuration: Int = call.argument("releaseDurationInMilliseconds")!!
        val revolutions: Double = call.argument("revolutions")!!
        val useExponentialCurve: Boolean = call.argument("useExponentialCurve")!!

        this.releaseDurationInMilliSeconds = releaseDuration
        this.revolutions = revolutions
        this.useExponentialCurve = useExponentialCurve

        createPatterns()
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
