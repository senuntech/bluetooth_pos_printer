package com.example.bluetooth_pos_printer

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.IOException
import java.io.OutputStream
import java.util.*
import kotlin.collections.ArrayList
import kotlin.collections.HashMap

class BluetoothPosPrinterPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, EventChannel.StreamHandler, PluginRegistry.RequestPermissionsResultListener {
  private lateinit var channel : MethodChannel
  private lateinit var eventChannel: EventChannel
  private var context: Context? = null
  private var activity: Activity? = null
  private var activityBinding: ActivityPluginBinding? = null
  private val REQUEST_SCAN_PERMISSION_CODE = 1001
  private val REQUEST_CONNECT_PERMISSION_CODE = 1002

  private var bluetoothAdapter: BluetoothAdapter? = null
  private var bluetoothSocket: BluetoothSocket? = null
  private var outputStream: OutputStream? = null

  private var eventSink: EventChannel.EventSink? = null
  private val uiThreadHandler = Handler(Looper.getMainLooper())

  private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
  private var isConnecting = false

  private var discoveredDevices = ArrayList<Map<String, String>>()
  private var scanResult: Result? = null
  private var connectResult: Result? = null
  private var connectAddress: String? = null
  private var discoveryReceiver: BroadcastReceiver? = null
  private var scanIncludePaired = true
  private var scanIncludeActive = true

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "samples.flutter.dev/bluetooth_pos_printer")
    channel.setMethodCallHandler(this)

    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "samples.flutter.dev/bluetooth_pos_printer/status")
    eventChannel.setStreamHandler(this)

    val bluetoothManager = context?.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    bluetoothAdapter = bluetoothManager?.adapter
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "isBluetoothEnabled" -> {
        try {
          result.success(bluetoothAdapter != null && bluetoothAdapter!!.isEnabled)
        } catch (e: SecurityException) {
          result.success(false)
        }
      }
      "scan" -> {
        val mode = call.argument<String>("mode") ?: "active"
        scanIncludePaired = (mode == "all" || mode == "paired")
        scanIncludeActive = (mode == "all" || mode == "active")
        scanDevices(result)
      }
      "connect" -> {
        val address = call.argument<String>("address")
        if (address != null) {
          connectToDevice(address, result)
        } else {
          result.error("INVALID_ADDRESS", "Address cannot be null", null)
        }
      }
      "disconnect" -> {
        disconnect(result)
      }
      "printRawBytes" -> {
        val bytes = call.argument<ByteArray>("bytes")
        if (bytes != null) {
          printBytes(bytes, result)
        } else {
          result.error("INVALID_DATA", "Bytes cannot be null", null)
        }
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
    if (discoveryReceiver != null) {
      try {
        bluetoothAdapter?.cancelDiscovery()
        context?.unregisterReceiver(discoveryReceiver)
      } catch (e: Exception) {
        // Ignore
      }
      discoveryReceiver = null
    }
    context = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    activityBinding = binding
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activityBinding?.removeRequestPermissionsResultListener(this)
    activityBinding = null
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    activityBinding = binding
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivity() {
    activityBinding?.removeRequestPermissionsResultListener(this)
    activityBinding = null
    activity = null
  }

  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
    if (requestCode == REQUEST_SCAN_PERMISSION_CODE) {
      val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
      val result = scanResult
      scanResult = null
      if (result != null) {
        if (allGranted) {
          scanDevices(result)
        } else {
          result.error("MISSING_PERMISSIONS", "Missing Bluetooth permissions for scanning", null)
        }
      }
      return true
    } else if (requestCode == REQUEST_CONNECT_PERMISSION_CODE) {
      val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
      val result = connectResult
      val address = connectAddress
      connectResult = null
      connectAddress = null
      if (result != null && address != null) {
        if (allGranted) {
          connectToDevice(address, result)
        } else {
          result.error("MISSING_PERMISSIONS", "Missing Bluetooth permissions for connecting", null)
        }
      }
      return true
    }
    return false
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }

  private fun updateStatus(status: String) {
    uiThreadHandler.post {
      eventSink?.success(status)
    }
  }

  @SuppressLint("MissingPermission")
  private fun stopDiscoveryAndSendResult(result: Result) {
    if (discoveryReceiver != null) {
      try {
        bluetoothAdapter?.cancelDiscovery()
        context?.unregisterReceiver(discoveryReceiver)
      } catch (e: Exception) {
        // Ignore if already unregistered
      }
      discoveryReceiver = null
      
      // Return paired + discovered devices
      result.success(ArrayList(discoveredDevices))
    }
  }

  @SuppressLint("MissingPermission")
  private fun scanDevices(result: Result) {
    if (!hasScanPermissions()) {
      if (activity == null) {
        result.error("MISSING_PERMISSIONS", "Missing Bluetooth permissions and activity is null", null)
        return
      }
      
      this.scanResult = result
      val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        arrayOf(Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_SCAN)
      } else {
        arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
      }
      
      ActivityCompat.requestPermissions(activity!!, permissions, REQUEST_SCAN_PERMISSION_CODE)
      return
    }

    if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
      result.error("BLUETOOTH_DISABLED", "Bluetooth is disabled", null)
      return
    }

    // Cancel any ongoing scan and return its result before starting a new one
    this.scanResult?.let {
      stopDiscoveryAndSendResult(it)
    }
    this.scanResult = result

    discoveredDevices.clear()
    
    // Add paired devices if includePaired is true
    if (scanIncludePaired) {
      val pairedDevices = bluetoothAdapter?.bondedDevices
      pairedDevices?.forEach { device ->
        val map = HashMap<String, String>()
        map["name"] = device.name ?: "Unknown"
        map["address"] = device.address
        map["type"] = getDeviceType(device)
        discoveredDevices.add(map)
      }
    }

    if (scanIncludeActive) {
      val filter = IntentFilter()
      filter.addAction(BluetoothDevice.ACTION_FOUND)
      filter.addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)

      discoveryReceiver = object : BroadcastReceiver() {
        @SuppressLint("MissingPermission")
        override fun onReceive(context: Context, intent: Intent) {
          val action = intent.action
          if (BluetoothDevice.ACTION_FOUND == action) {
            val device: BluetoothDevice? = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
            if (device != null) {
              val deviceName = device.name ?: "Unknown"
              val deviceAddress = device.address
              val alreadyExists = discoveredDevices.any { it["address"] == deviceAddress }
              if (!alreadyExists) {
                val map = HashMap<String, String>()
                map["name"] = deviceName
                map["address"] = deviceAddress
                map["type"] = getDeviceType(device)
                discoveredDevices.add(map)
              }
            }
          } else if (BluetoothAdapter.ACTION_DISCOVERY_FINISHED == action) {
            stopDiscoveryAndSendResult(result)
          }
        }
      }

      context?.registerReceiver(discoveryReceiver, filter)
      
      try {
        bluetoothAdapter?.startDiscovery()
      } catch (e: SecurityException) {
        result.error("SECURITY_EXCEPTION", "SecurityException during discovery: ${e.message}", null)
        return
      }

      // 4 seconds active scan timeout
      uiThreadHandler.postDelayed({
        stopDiscoveryAndSendResult(result)
      }, 4000)
    } else {
      // If active scan is not requested, return immediately with the paired devices
      scanResult = null
      result.success(ArrayList(discoveredDevices))
    }
  }

  @SuppressLint("MissingPermission")
  private fun connectToDevice(address: String, result: Result) {
    if (!hasConnectPermissions()) {
      if (activity == null) {
        result.error("MISSING_PERMISSIONS", "Missing Bluetooth permissions and activity is null", null)
        return
      }
      
      this.connectAddress = address
      this.connectResult = result
      
      val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        arrayOf(Manifest.permission.BLUETOOTH_CONNECT)
      } else {
        arrayOf()
      }
      
      if (permissions.isNotEmpty()) {
        ActivityCompat.requestPermissions(activity!!, permissions, REQUEST_CONNECT_PERMISSION_CODE)
      } else {
        connectToDevice(address, result)
      }
      return
    }

    if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
      result.error("BLUETOOTH_DISABLED", "Bluetooth is disabled", null)
      return
    }

    if (isConnecting || bluetoothSocket?.isConnected == true) {
      disconnectInternal()
    }

    isConnecting = true
    updateStatus("connecting")

    Thread {
      try {
        val device: BluetoothDevice = bluetoothAdapter!!.getRemoteDevice(address)
        bluetoothSocket = device.createRfcommSocketToServiceRecord(SPP_UUID)
        
        bluetoothAdapter?.cancelDiscovery()
        bluetoothSocket?.connect()
        outputStream = bluetoothSocket?.outputStream
        
        isConnecting = false
        updateStatus("connected")
        uiThreadHandler.post {
          result.success(true)
        }
      } catch (e: Exception) {
        isConnecting = false
        disconnectInternal()
        updateStatus("disconnected")
        uiThreadHandler.post {
          result.error("CONNECTION_FAILED", e.message, null)
        }
      }
    }.start()
  }

  private fun disconnectInternal() {
    try {
      outputStream?.close()
      bluetoothSocket?.close()
    } catch (e: Exception) {
      // Ignore
    } finally {
      outputStream = null
      bluetoothSocket = null
      updateStatus("disconnected")
    }
  }

  private fun disconnect(result: Result) {
    disconnectInternal()
    result.success(true)
  }

  private fun printBytes(bytes: ByteArray, result: Result) {
    if (bluetoothSocket == null || !bluetoothSocket!!.isConnected || outputStream == null) {
      result.error("NOT_CONNECTED", "Printer is not connected", null)
      return
    }

    Thread {
      try {
        val chunkSize = 256
        var offset = 0
        while (offset < bytes.size) {
          val end = Math.min(offset + chunkSize, bytes.size)
          val chunk = bytes.copyOfRange(offset, end)
          outputStream?.write(chunk)
          outputStream?.flush()
          offset += chunkSize
          // Small delay to prevent buffer overflow on old printers
          Thread.sleep(10)
        }
        uiThreadHandler.post {
          result.success(true)
        }
      } catch (e: Exception) {
        disconnectInternal()
        uiThreadHandler.post {
          result.error("PRINT_FAILED", e.message, null)
        }
      }
    }.start()
  }

  private fun hasScanPermissions(): Boolean {
    if (context == null) return false
    
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      val pScan = ContextCompat.checkSelfPermission(context!!, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
      val pConnect = ContextCompat.checkSelfPermission(context!!, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
      pScan && pConnect
    } else {
      ContextCompat.checkSelfPermission(context!!, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }
  }

  private fun hasConnectPermissions(): Boolean {
    if (context == null) return false
    
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      ContextCompat.checkSelfPermission(context!!, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
    } else {
      true
    }
  }

  private fun getDeviceType(device: BluetoothDevice): String {
    val btClass = device.bluetoothClass ?: return "unknown"
    val majorClass = btClass.majorDeviceClass
    val deviceClass = btClass.deviceClass
    
    return when {
      deviceClass == 1664 || majorClass == BluetoothClass.Device.Major.IMAGING -> "printer"
      majorClass == BluetoothClass.Device.Major.COMPUTER -> "computer"
      majorClass == BluetoothClass.Device.Major.PHONE -> "phone"
      majorClass == BluetoothClass.Device.Major.AUDIO_VIDEO -> "audio"
      majorClass == BluetoothClass.Device.Major.PERIPHERAL -> "peripheral"
      else -> "unknown"
    }
  }
}
