package com.example.tagbox

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Bundle
import android.util.Log
import kotlin.text.Regex

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.tagbox/share"
    private var sharedText: String? = null
    private var methodChannel: MethodChannel? = null
    private var isFlutterEngineReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d("MainActivity", "Configuring Flutter engine")
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedText" -> {
                    Log.d("MainActivity", "getSharedText called, returning: $sharedText")
                    result.success(sharedText)
                }
                "clearSharedText" -> {
                    Log.d("MainActivity", "clearSharedText called")
                    sharedText = null
                    result.success(null)
                }
                else -> {
                    Log.d("MainActivity", "Unknown method called: ${call.method}")
                    result.notImplemented()
                }
            }
        }

        isFlutterEngineReady = true
        Log.d("MainActivity", "Flutter engine ready, checking for pending shared text")
        sendPendingSharedText()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MainActivity", "onCreate called with intent: ${intent?.action}")
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d("MainActivity", "onNewIntent called with action: ${intent.action}")
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        Log.d("MainActivity", "handleIntent called with action: ${intent?.action}")
        when (intent?.action) {
            Intent.ACTION_SEND -> {
                if (intent.type == "text/plain") {
                    var text = intent.getStringExtra(Intent.EXTRA_TEXT)
                    Log.d("MainActivity", "Raw shared text: $text")
                    
                    // Clean up the text if needed
                    text = text?.trim()
                    Log.d("MainActivity", "Trimmed text: $text")
                    
                    // Extract URL if the shared text contains additional information
                    if (text?.contains("http") == true) {
                        // Updated regex pattern to better handle social media URLs
                        val urlPattern = Regex("https?://(?:www\\.)?(?:facebook\\.com|fb\\.watch|instagram\\.com|tiktok\\.com|youtube\\.com|youtu\\.be)[^\\s\"]+")
                        val matchResults = urlPattern.findAll(text)
                        val urls = matchResults.map { it.value.trim() }.toList()
                        
                        if (urls.isNotEmpty()) {
                            // Take the first valid URL
                            text = urls[0].split(" ")[0] // Split by space and take first part to handle any trailing text
                            Log.d("MainActivity", "Extracted clean URL from shared text: $text")
                            
                            // Remove any trailing punctuation or invalid characters
                            text = text.replace(Regex("[,.!?\"']+$"), "")
                            Log.d("MainActivity", "Final cleaned URL: $text")
                        } else {
                            Log.d("MainActivity", "No valid social media URL found in text")
                        }
                    } else {
                        Log.d("MainActivity", "Text does not contain http")
                    }
                    
                    if (!text.isNullOrEmpty()) {
                        sharedText = text
                        Log.d("MainActivity", "Final shared text to be sent: $sharedText")
                        sendPendingSharedText()
                    } else {
                        Log.d("MainActivity", "Text is null or empty after processing")
                    }
                } else {
                    Log.d("MainActivity", "Intent type is not text/plain: ${intent.type}")
                }
            }
            else -> Log.d("MainActivity", "Unhandled intent action: ${intent?.action}")
        }
    }

    private fun sendPendingSharedText() {
        Log.d("MainActivity", "Attempting to send pending shared text. Engine ready: $isFlutterEngineReady, Text: $sharedText")
        if (isFlutterEngineReady && sharedText != null) {
            Log.d("MainActivity", "Sending shared text through method channel")
            methodChannel?.invokeMethod("onSharedTextReceived", sharedText)
        } else {
            Log.d("MainActivity", "Cannot send shared text yet. Engine ready: $isFlutterEngineReady, Text: $sharedText")
        }
    }
} 