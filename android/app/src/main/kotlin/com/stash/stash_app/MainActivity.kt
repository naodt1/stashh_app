package com.stash.stash_app

import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        publishDirectShareShortcut()
    }

    /**
     * Publishes a Dynamic Sharing Shortcut so Stash appears in the
     * TOP ROW of the Android share sheet (Direct Share section).
     * Requires API 25+; silently skipped on older devices.
     */
    private fun publishDirectShareShortcut() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return

        val shortcutManager = getSystemService(ShortcutManager::class.java) ?: return

        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = "*/*"
            setPackage(packageName)
        }

        val shortcut = ShortcutInfo.Builder(this, "stash_save")
            .setShortLabel("Save to Stash")
            .setLongLabel("Save to Stash")
            .setIcon(Icon.createWithResource(this, R.mipmap.ic_launcher))
            .setIntent(shareIntent)
            .setCategories(setOf("com.stash.stash_app.directshare.SAVE"))
            .build()

        try {
            shortcutManager.addDynamicShortcuts(listOf(shortcut))
        } catch (_: Exception) {
            // Quota exceeded or other error — not critical
        }
    }
}
