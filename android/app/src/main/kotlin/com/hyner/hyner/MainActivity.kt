package com.hyner.hyner

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.ClipboardManager
import android.os.PersistableBundle
import android.content.ClipData
import android.net.Uri
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.SystemClock
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.atomic.AtomicLong

class MainActivity : FlutterActivity() {
    private var notificationPermissionResult: MethodChannel.Result? = null
    private var profilePhotoResult: MethodChannel.Result? = null
    private var profilePhotoUid: String? = null
    private var billPdfResult: MethodChannel.Result? = null
    private var billPdfBytes: ByteArray? = null
    private val fileWork = FileWorkQueue { action -> runOnUiThread(action) }
    // Current-process handoffs are protected for the whole process, even if very old.
    private val sharePrefix = SHARE_SESSION_PREFIX

    override fun onDestroy() {
        fileWork.close()
        for (pending in listOf(notificationPermissionResult, profilePhotoResult, billPdfResult)) {
            pending?.error("activity-closed", "The activity closed before the operation completed.", null)
        }
        notificationPermissionResult = null
        profilePhotoResult = null
        profilePhotoUid = null
        billPdfResult = null
        billPdfBytes = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannel()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hyner/bill_pdf")
            .setMethodCallHandler { call, result ->
                if (call.method !in listOf("shareWhatsApp", "savePdf", "copyPdf")) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val filename = call.argument<String>("filename").orEmpty()
                    .replace(Regex("[^A-Za-z0-9._-]"), "_")
                if (bytes == null || bytes.size < 5 || bytes.size > 25 * 1024 * 1024 ||
                    !filename.endsWith(".pdf") || filename.length > 160 ||
                    !bytes.copyOfRange(0, 5).contentEquals("%PDF-".toByteArray())
                ) {
                    result.error("invalid-pdf", "A valid PDF is required.", null)
                    return@setMethodCallHandler
                }
                if (call.method == "shareWhatsApp" || call.method == "copyPdf") {
                    val enteredPhone = call.argument<String>("phone")?.filter { it.isDigit() }.orEmpty()
                    val phone = if (enteredPhone.length == 10) "91$enteredPhone" else enteredPhone
                    if (phone.isNotEmpty() && phone.length !in 8..15) {
                        result.error("invalid-phone", "Enter a valid customer mobile number.", null)
                        return@setMethodCallHandler
                    }
                    shareBillPdf(bytes, filename, result, call.method == "copyPdf", phone)
                } else {
                    if (billPdfResult != null) {
                        result.error("save-open", "A PDF save dialog is already open.", null)
                        return@setMethodCallHandler
                    }
                    billPdfResult = result
                    billPdfBytes = bytes
                    try {
                        startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/pdf"
                            putExtra(Intent.EXTRA_TITLE, filename)
                        }, BILL_PDF_REQUEST)
                    } catch (_: Exception) {
                        billPdfResult = null
                        billPdfBytes = null
                        result.error("save-unavailable", "No document picker is available.", null)
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hyner.hyner/share")
            .setMethodCallHandler { call, result ->
                if (call.method != "shareText") {
                    result.notImplemented()
                } else {
                    val text = call.argument<String>("text")
                    if (text.isNullOrBlank() || text.length > 20000) {
                        result.error("invalid_text", "Complete the calculation before sharing", null)
                    } else {
                        try {
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            startActivity(Intent.createChooser(intent, "Share price"))
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("share_unavailable", "No sharing application is available", null)
                        }
                    }
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hyner/whatsapp")
            .setMethodCallHandler { call, result ->
                if (call.method != "openChat") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val enteredPhone = call.argument<String>("phone")?.filter { it.isDigit() }.orEmpty()
                val phone = if (enteredPhone.length == 10) "91$enteredPhone" else enteredPhone
                val message = call.argument<String>("message").orEmpty()
                if (phone.length !in 8..15 || message.isBlank()) {
                    result.error("invalid-input", "Enter an international phone number and a message.", null)
                    return@setMethodCallHandler
                }
                val uri = Uri.parse("https://wa.me/$phone")
                    .buildUpon()
                    .appendQueryParameter("text", message)
                    .build()
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, uri))
                    result.success(null)
                } catch (_: ActivityNotFoundException) {
                    result.error("unavailable", "No app can open this WhatsApp link.", null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hyner/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isEnabled" -> result.success(notificationsEnabled())
                    "requestPermission" -> requestNotificationPermission(result)
                    "openSettings" -> openNotificationSettings(result)
                    "show" -> showNotification(call, result)
                    "cancel" -> {
                        val id = call.argument<Int>("id")
                        if (id == null) {
                            result.error("invalid-input", "A notification ID is required.", null)
                        } else {
                            getSystemService(NotificationManager::class.java).cancel(id)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hyner/media")
            .setMethodCallHandler { call, result ->
                if (call.method != "pickProfilePhoto") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val uid = call.argument<String>("uid")?.trim().orEmpty()
                if (uid.isEmpty()) {
                    result.error("invalid-input", "Sign in before choosing a profile photo.", null)
                    return@setMethodCallHandler
                }
                if (profilePhotoResult != null) {
                    result.error("picker-open", "The photo picker is already open.", null)
                    return@setMethodCallHandler
                }
                profilePhotoUid = uid
                profilePhotoResult = result
                try {
                    val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                        type = "image/*"
                        addCategory(Intent.CATEGORY_OPENABLE)
                    }
                    startActivityForResult(
                        Intent.createChooser(intent, "Choose a profile photo"),
                        PROFILE_PHOTO_REQUEST,
                    )
                } catch (_: ActivityNotFoundException) {
                    profilePhotoResult = null
                    profilePhotoUid = null
                    result.error("unavailable", "No photo picker is available on this device.", null)
                }
            }
    }

    @Deprecated("Deprecated in Android API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == BILL_PDF_REQUEST) {
            val result = billPdfResult
            val bytes = billPdfBytes
            billPdfResult = null
            billPdfBytes = null
            if (result == null) return
            val uri = data?.data
            if (resultCode != RESULT_OK || uri == null || bytes == null) {
                result.success(null)
                return
            }
            fileWork.submit(
                action = {
                    val output = contentResolver.openOutputStream(uri, "wt")
                        ?: throw IllegalStateException("The PDF destination could not be opened.")
                    output.use { it.write(bytes) }
                    uri.toString()
                },
                success = { result.success(it) },
                failure = { result.error("save-failed", "The PDF could not be written to this location.", null) },
            )
            return
        }
        if (requestCode != PROFILE_PHOTO_REQUEST) return
        val result = profilePhotoResult
        val uid = profilePhotoUid
        profilePhotoResult = null
        profilePhotoUid = null
        if (result == null) return
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null || uid == null) {
            result.success(null)
            return
        }
        fileWork.submit(
            action = { saveProfilePhoto(uri, uid) },
            success = { result.success(it) },
            failure = { error -> result.error("photo-save", "The selected photo could not be saved on this device.", error.message) },
        )
    }

    private fun shareBillPdf(bytes: ByteArray, filename: String, result: MethodChannel.Result, copy: Boolean, phone: String) {
        fileWork.submit(
            action = {
                val directory = File(cacheDir, "share")
                if (!directory.exists() && !directory.mkdirs()) {
                    throw IllegalStateException("The PDF share folder could not be created.")
                }
                val elapsed = SystemClock.elapsedRealtime()
                val lastCleanup = SHARE_CLEANUP_ELAPSED.get()
                if ((lastCleanup < 0 || elapsed - lastCleanup >= 24L * 60 * 60 * 1000) &&
                    SHARE_CLEANUP_ELAPSED.compareAndSet(lastCleanup, elapsed)
                ) {
                    try { SharedTempFiles.clean(directory, sharePrefix, System.currentTimeMillis()) }
                    catch (_: Exception) { /* Cleanup is never required to share. */ }
                }
                val file = File.createTempFile(sharePrefix, ".pdf", directory)
                FileOutputStream(file).use { it.write(bytes) }
                // Resolve the existing printing FileProvider only after the file is closed.
                FileProvider.getUriForFile(this, "$packageName.flutter.printing", file)
            },
            success = { uri ->
                if (copy) {
                    try {
                        val clip = ClipData.newUri(contentResolver, filename, uri)
                        clip.description.extras = PersistableBundle().apply {
                            putBoolean("android.content.extra.IS_SENSITIVE", true)
                        }
                        getSystemService(ClipboardManager::class.java).setPrimaryClip(clip)
                        result.success(null)
                    } catch (_: Exception) {
                        result.error("copy-unavailable", "This device could not copy the PDF. Use Download or Share instead.", null)
                    }
                } else openBillShare(uri, filename, phone, result)
            },
            failure = { result.error("share-unavailable", "The PDF could not be shared.", null) },
        )
    }

    private fun openBillShare(uri: Uri, filename: String, phone: String, result: MethodChannel.Result) {
        try {
            fun intent() = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_SUBJECT, filename)
                clipData = ClipData.newRawUri(filename, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            for (target in listOf("com.whatsapp", "com.whatsapp.w4b")) {
                try {
                    val targeted = intent().setPackage(target)
                    // Best-effort recipient hint; WhatsApp owns its confirmation UI.
                    if (phone.isNotEmpty()) targeted.putExtra("jid", "$phone@s.whatsapp.net")
                    startActivity(targeted)
                    result.success(null)
                    return
                } catch (_: ActivityNotFoundException) {
                    // Try WhatsApp Business, then the system share sheet.
                }
            }
            startActivity(Intent.createChooser(intent(), "Share PDF"))
            result.success(null)
        } catch (_: Exception) {
            result.error("share-unavailable", "The PDF could not be shared.", null)
        }
    }

    private fun saveProfilePhoto(uri: Uri, uid: String): String {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        contentResolver.openInputStream(uri).use { input ->
            if (input == null) throw IllegalStateException("The selected image could not be opened.")
            BitmapFactory.decodeStream(input, null, bounds)
        }
        if (bounds.outWidth < 1 || bounds.outHeight < 1) {
            throw IllegalArgumentException("The selected file is not a readable image.")
        }
        val maxDimension = 1024
        var sampleSize = 1
        while (bounds.outWidth / sampleSize > maxDimension ||
            bounds.outHeight / sampleSize > maxDimension
        ) sampleSize *= 2
        val bitmap = contentResolver.openInputStream(uri).use { input ->
            if (input == null) throw IllegalStateException("The selected image could not be opened.")
            BitmapFactory.decodeStream(
                input,
                null,
                BitmapFactory.Options().apply { inSampleSize = sampleSize },
            ) ?: throw IllegalArgumentException("The selected image could not be decoded.")
        }
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(uid.toByteArray())
            .joinToString("") { byte -> "%02x".format(byte) }
        val directory = File(filesDir, "profile-images")
        if (!directory.exists() && !directory.mkdirs()) {
            bitmap.recycle()
            throw IllegalStateException("The profile image folder could not be created.")
        }
        val file = File(directory, "$digest.jpg")
        try {
            FileOutputStream(file).use { output ->
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 86, output)) {
                    throw IllegalStateException("The selected image could not be compressed.")
                }
            }
        } finally {
            bitmap.recycle()
        }
        return file.absolutePath
    }

    private fun notificationsEnabled(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return false
        return getSystemService(NotificationManager::class.java).areNotificationsEnabled()
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(notificationsEnabled())
            return
        }
        if (notificationPermissionResult != null) {
            result.error("permission-pending", "A notification permission request is already open.", null)
            return
        }
        notificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    @Deprecated("Deprecated in Android API")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST) {
            notificationPermissionResult?.success(
                grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED && notificationsEnabled(),
            )
            notificationPermissionResult = null
        }
    }

    private fun openNotificationSettings(result: MethodChannel.Result) {
        try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.parse("package:$packageName"))
            }
            startActivity(intent)
            result.success(null)
        } catch (_: ActivityNotFoundException) {
            result.error("unavailable", "Notification settings could not be opened.", null)
        }
    }

    private fun showNotification(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        if (!notificationsEnabled()) {
            result.success(false)
            return
        }
        val id = call.argument<Int>("id")
        val title = call.argument<String>("title")?.trim().orEmpty()
        val body = call.argument<String>("body")?.trim().orEmpty()
        if (id == null || title.isEmpty() || body.isEmpty()) {
            result.error("invalid-input", "A notification title and message are required.", null)
            return
        }
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                id,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL)
        } else {
            Notification.Builder(this)
        }
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setPriority(Notification.PRIORITY_HIGH)
        if (contentIntent != null) builder.setContentIntent(contentIntent)
        try {
            getSystemService(NotificationManager::class.java).notify(id, builder.build())
            result.success(true)
        } catch (_: SecurityException) {
            result.success(false)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL,
            "Hyner business alerts",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Low stock and saved business activity alerts"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    companion object {
        private val SHARE_CLEANUP_ELAPSED = AtomicLong(-1L)
        private val SHARE_SESSION_PREFIX = "bill-${UUID.randomUUID()}-"
        private const val NOTIFICATION_CHANNEL = "hyner_business_alerts"
        private const val NOTIFICATION_PERMISSION_REQUEST = 4127
        private const val PROFILE_PHOTO_REQUEST = 4128
        private const val BILL_PDF_REQUEST = 4129
    }
}
