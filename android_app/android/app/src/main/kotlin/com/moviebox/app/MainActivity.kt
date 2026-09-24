package com.moviebox.app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.moviebox.app/player"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchPlayer" -> {
                    val url = call.argument<String>("url")
                    val player = call.argument<String>("player") ?: "chooser"
                    val title = call.argument<String>("title")
                    val headersMap = call.argument<Map<String, String>>("headers")
                    val subtitleUrl = call.argument<String>("subtitleUrl")

                    if (url.isNullOrEmpty()) {
                        result.error("INVALID_URL", "Stream URL is empty", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(Uri.parse(url), "video/*")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

                            if (!title.isNullOrEmpty()) {
                                putExtra("title", title)
                                putExtra("android.intent.extra.TITLE", title)
                            }

                            if (!subtitleUrl.isNullOrEmpty()) {
                                putExtra("subs", Uri.parse(subtitleUrl))
                                putExtra("subtitles_location", subtitleUrl)
                                putExtra("subs.enable", arrayOf(Uri.parse(subtitleUrl)))
                            }

                            // Pass custom headers for players that support it (VLC, MX Player, etc.)
                            if (headersMap != null && headersMap.isNotEmpty()) {
                                val headersArray = ArrayList<String>()
                                val headersBundle = Bundle()
                                for ((k, v) in headersMap) {
                                    headersArray.add(k)
                                    headersArray.add(v)
                                    headersBundle.putString(k, v)
                                }
                                putExtra("headers", headersArray.toTypedArray())
                                putExtra("android.media.intent.extra.HTTP_HEADERS", headersBundle)
                            }
                        }

                        // Start Foreground Service to keep streaming proxy alive while external player is running
                        val serviceIntent = Intent(this@MainActivity, PlaybackService::class.java).apply {
                            putExtra("title", title ?: "MovieMania Streaming")
                        }
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }

                        when (player.lowercase()) {
                            "mpv" -> {
                                intent.setPackage("is.xyz.mpv")
                                startActivity(intent)
                                result.success(true)
                            }
                            "vlc" -> {
                                intent.setPackage("org.videolan.vlc")
                                startActivity(intent)
                                result.success(true)
                            }
                            else -> {
                                val chooser = Intent.createChooser(intent, title ?: "Play Video")
                                chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(chooser)
                                result.success(true)
                            }
                        }
                    } catch (e: ActivityNotFoundException) {
                        stopService(Intent(this@MainActivity, PlaybackService::class.java))
                        result.error(
                            "PLAYER_NOT_INSTALLED",
                            "Selected player '$player' is not installed on this device.",
                            null
                        )
                    } catch (e: Exception) {
                        stopService(Intent(this@MainActivity, PlaybackService::class.java))
                        result.error(
                            "LAUNCH_FAILED",
                            "Failed to launch player: ${e.localizedMessage}",
                            null
                        )
                    }
                }
                "stopPlaybackService" -> {
                    stopService(Intent(this@MainActivity, PlaybackService::class.java))
                    result.success(true)
                }
                "isPlayerInstalled" -> {
                    val player = call.argument<String>("player") ?: ""
                    val packageName = when (player.lowercase()) {
                        "mpv" -> "is.xyz.mpv"
                        "vlc" -> "org.videolan.vlc"
                        else -> null
                    }

                    if (packageName == null) {
                        result.success(true) // Chooser is always available
                    } else {
                        val installed = try {
                            packageManager.getPackageInfo(packageName, 0)
                            true
                        } catch (e: Exception) {
                            false
                        }
                        result.success(installed)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
