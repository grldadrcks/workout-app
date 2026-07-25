package com.mason.workout_app

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import com.lf.api.CardioEquipmentInfo
import com.lf.api.DataServiceConnectionListener
import com.lf.api.ENVIRONMENT
import com.lf.api.EquipmentObserver
import com.lf.api.LfconnectDataService
import com.lf.api.WorkoutManager
import com.lf.api.WorkoutResult
import com.lf.api.models.EquipmentInformation
import com.lf.api.models.EquipmentState
import com.lf.api.models.ReplayableResult
import com.lf.api.models.WorkoutPreset
import com.lf.api.models.WorkoutStream
import com.lf.ble.lfopen2.ftms.Constants
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class LFEquipmentPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler, ActivityAware, EquipmentObserver {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var activity: android.app.Activity? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private val foundDevices = mutableListOf<ScanResult>()
    private var scanning = false
    private var serviceReady = false  // true once LfconnectDataService.onSuccess fires

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val uuids = result.scanRecord?.serviceUuids ?: return
            if (uuids.isEmpty()) return
            val uuid = uuids[0].uuid
            if (WorkoutManager.isLFBLE(uuid)) {
                addOrUpdate(result)
            }
        }
    }

    // ── FlutterPlugin ───────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "lf_equipment")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "lf_equipment/stream")
        eventChannel.setStreamHandler(this)

        LfconnectDataService().initialize(
            binding.applicationContext,
            "3086-8210144929-2230",
            ENVIRONMENT.useProd(),
            object : DataServiceConnectionListener {
                override fun onError(errorCode: Int, description: String) {
                    Log.w("LFEquipment", "Cloud init error ($errorCode): $description")
                    // Still allow BLE use even if cloud auth fails
                    onServiceReady()
                }
                override fun onSuccess() {
                    Log.d("LFEquipment", "Cloud service ready")
                    onServiceReady()
                }
            }
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    // ── ActivityAware ───────────────────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        if (serviceReady) attachWorkoutManager(binding.activity)
        // else: onServiceReady() will call attachWorkoutManager once the callback fires
    }

    override fun onDetachedFromActivity() {
        stopScanAndDisconnect()
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    private fun onServiceReady() {
        serviceReady = true
        val act = activity ?: return
        mainHandler.post { attachWorkoutManager(act) }
    }

    private fun attachWorkoutManager(act: android.app.Activity) {
        WorkoutManager.getInstance().attachToContext(act)
        WorkoutManager.getInstance().init()
    }

    // ── MethodChannel ───────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> startScan(result)
            "disconnect" -> { stopScanAndDisconnect(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    // ── EventChannel ────────────────────────────────────────────────────────

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // ── BLE scan & connect ──────────────────────────────────────────────────

    private fun startScan(result: MethodChannel.Result) {
        val act = activity ?: run {
            result.error("NO_ACTIVITY", "No activity available", null)
            return
        }

        if (!hasBluetoothPermissions(act)) {
            result.error("NO_PERMISSION", "Bluetooth permissions not granted. Please grant them in Settings.", null)
            return
        }

        val btManager = act.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        bluetoothAdapter = btManager?.adapter
        if (bluetoothAdapter?.isEnabled != true) {
            result.error("BT_DISABLED", "Bluetooth is not enabled", null)
            return
        }

        WorkoutManager.getInstance().registerObserver(this)
        foundDevices.clear()
        scanning = true
        sendEvent(mapOf("type" to "scanning"))

        bluetoothAdapter!!.bluetoothLeScanner?.startScan(scanCallback)

        // After 5 s, stop scanning and connect to the nearest found device
        mainHandler.postDelayed({
            if (!scanning) return@postDelayed
            bluetoothAdapter?.bluetoothLeScanner?.stopScan(scanCallback)
            scanning = false

            if (foundDevices.isEmpty()) {
                sendEvent(mapOf("type" to "error", "message" to "No Life Fitness equipment found nearby"))
            } else {
                connectToNearest()
            }
        }, 5000)

        result.success(null)
    }

    private fun connectToNearest() {
        val nearest = getNearestDevice() ?: return
        val uuid = nearest.scanRecord?.serviceUuids?.getOrNull(0)?.uuid ?: return

        val lfOpenVersion = when (uuid) {
            WorkoutManager.UUID_WAHOO -> Integer.valueOf(WorkoutManager.LFOPEN_SERIES_WAHOO)
            Constants.uuidServiceFTMS -> Integer.valueOf(WorkoutManager.LFOPEN_SERIES_LOPEN2)
            else -> Integer.valueOf(WorkoutManager.LFOPEN_SERIES_LOPEN1)
        }

        try {
            WorkoutManager.getInstance().connectBluetoothLE(nearest.device, lfOpenVersion)
        } catch (e: Exception) {
            sendEvent(mapOf("type" to "error", "message" to (e.message ?: "Connection failed")))
        }
    }

    private fun stopScanAndDisconnect() {
        if (scanning) {
            bluetoothAdapter?.bluetoothLeScanner?.stopScan(scanCallback)
            scanning = false
        }
        WorkoutManager.getInstance().unregisterObserver(this)
        WorkoutManager.getInstance().stop()
        sendEvent(mapOf("type" to "disconnected"))
    }

    private fun getNearestDevice(): ScanResult? = foundDevices.maxByOrNull { result ->
        var rssi = result.rssi.toDouble()
        val uuid = result.scanRecord?.serviceUuids?.getOrNull(0)?.uuid
        if (uuid == WorkoutManager.UUID_WAHOO) rssi *= 0.8
        rssi
    }

    private fun addOrUpdate(result: ScanResult) {
        synchronized(foundDevices) {
            val idx = foundDevices.indexOfFirst { it.device.address == result.device.address }
            if (idx >= 0) foundDevices[idx] = result else foundDevices.add(result)
        }
    }

    private fun hasBluetoothPermissions(ctx: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun sendEvent(data: Map<String, Any?>) {
        mainHandler.post { eventSink?.success(data) }
    }

    // ── EquipmentObserver ───────────────────────────────────────────────────

    override fun onInit() {}
    override fun onConnection() {}

    override fun onConnected(lfopenversion: Int, information: EquipmentInformation?) {
        val protocol = when (lfopenversion) {
            Integer.valueOf(WorkoutManager.LFOPEN_SERIES_LOPEN2) -> "LFOpen 2"
            Integer.valueOf(WorkoutManager.LFOPEN_SERIES_WAHOO) -> "Wahoo"
            else -> "LFOpen 1"
        }
        sendEvent(mapOf(
            "type" to "connected",
            "protocol" to protocol,
            "serial" to (information?.bodySerial ?: ""),
            "csafeId" to (information?.lifefitnessCsafeId ?: 0)
        ))
    }

    override fun onSendingWorkoutPreset(): List<WorkoutPreset> = emptyList()
    override fun onWorkoutPresetSent(index: Int) {}
    override fun onWorkoutResultReceived(workoutresult: WorkoutResult?) {}

    override fun onStreamReceived(workoutstream: WorkoutStream?) {
        workoutstream ?: return
        sendEvent(mapOf(
            "type" to "stream",
            "speed" to workoutstream.currentSpeedKph,
            "distance" to workoutstream.accumulatedDistance,
            "calories" to workoutstream.accumulatedCalories,
            "duration" to workoutstream.workoutElapseSeconds
        ))
    }

    override fun onDisconnected() {
        sendEvent(mapOf("type" to "disconnected"))
    }

    override fun onError(e: Exception?) {
        sendEvent(mapOf("type" to "error", "message" to (e?.message ?: "Unknown error")))
    }

    override fun onDisplaySettingsRequest() {}
    override fun onWorkoutResultStartTransfer(percent: Float) {}
    override fun onAutologinSent() {}
    override fun onWorkoutPaused() { sendEvent(mapOf("type" to "paused")) }
    override fun onWorkoutResume() { sendEvent(mapOf("type" to "resumed")) }
    override fun onEquipmentIdle() {}
    override fun onWahooEquipmentType(type: Int) {}
    override fun onWahooCSafeIDRetrieved(csafeId: Int) {}
    override fun onAck(command: Byte, status: Int) {}
    override fun onLfopen2StateChange(state: EquipmentState?) {}
    override fun onEquipmentInfo(info: CardioEquipmentInfo?) {}
    override fun onSendingReplayableResults(equipmentId: Int): List<ReplayableResult> = emptyList()
    override fun onUserUpdateFromConsole() {}
}
