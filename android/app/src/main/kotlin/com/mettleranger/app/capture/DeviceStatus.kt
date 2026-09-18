package com.mettleranger.app.capture

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.os.StatFs

/**
 * Free space, battery and thermal reads for the storage/thermal/battery
 * guards in spec §7. Static Context queries only — none of this needs the
 * capture service to be running, so Setup can check before a session even
 * starts.
 */
object DeviceStatus {
    /** The directory recordings are written to. App-private; never a shared
     * or gallery-visible location (spec §7). Falls back to internal storage
     * on the (rare, pre-scoped-storage-irrelevant at minSdk 29) chance
     * external app-specific storage is unavailable. */
    fun recordingsDir(context: Context) =
        context.getExternalFilesDir("recordings") ?: context.filesDir

    fun freeStorageBytes(context: Context): Long =
        StatFs(recordingsDir(context).path).availableBytes

    fun batteryPercent(context: Context): Int {
        val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val level = batteryManager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        if (level != null && level in 0..100) return level

        // Fallback via the sticky battery-changed broadcast, for the rare
        // device where the BatteryManager property isn't populated.
        val intent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val rawLevel = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        return if (rawLevel >= 0 && scale > 0) (rawLevel * 100 / scale) else 100
    }

    /**
     * Ordinal matching Dart's `ThermalLevel` enum exactly:
     * PowerManager.THERMAL_STATUS_NONE..SHUTDOWN is 0..6 in the same order
     * as `enum ThermalLevel { none, light, moderate, severe, critical,
     * emergency, shutdown }` — no translation table needed.
     *
     * `currentThermalStatus` itself is API 29+, which is this app's floor
     * (spec §7 needs it; see build.gradle.kts's minSdk note), so there is no
     * pre-29 branch to reconcile — this always returns a real reading.
     */
    fun thermalStatusOrdinal(context: Context): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return 0
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        return powerManager?.currentThermalStatus ?: 0
    }
}
