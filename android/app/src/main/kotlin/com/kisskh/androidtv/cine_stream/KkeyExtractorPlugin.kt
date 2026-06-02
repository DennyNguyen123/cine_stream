package com.kisskh.androidtv.cine_stream

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class KkeyExtractorPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val baseUrl = "https://kisskh.co"

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "cine_stream/kkey")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "extractKkey") {
            val dramaId = call.argument<Int>("dramaId")
            val episodeId = call.argument<Int>("episodeId")
            if (dramaId != null && episodeId != null) {
                extractKkey(dramaId, episodeId, result)
            } else {
                result.error("INVALID_ARGUMENTS", "dramaId and episodeId are required", null)
            }
        } else {
            result.notImplemented()
        }
    }

    private fun extractKkey(dramaId: Int, episodeId: Int, result: Result) {
        Handler(Looper.getMainLooper()).post {
            val webView = WebView(context)
            var isCompleted = false
            var streamKey: String? = null
            var subKey: String? = null

            val handler = Handler(Looper.getMainLooper())
            val timeoutRunnable = Runnable {
                if (!isCompleted) {
                    isCompleted = true
                    webView.stopLoading()
                    webView.destroy()
                    result.success(mapOf("streamKkey" to streamKey, "subKkey" to subKey))
                }
            }
            
            // 15 seconds timeout
            handler.postDelayed(timeoutRunnable, 15000)

            webView.settings.javaScriptEnabled = true
            webView.settings.domStorageEnabled = true
            webView.settings.userAgentString = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

            webView.webViewClient = object : WebViewClient() {
                override fun shouldInterceptRequest(
                    view: WebView?,
                    request: WebResourceRequest?
                ): WebResourceResponse? {
                    val url = request?.url?.toString()
                    if (url != null) {
                        if (url.contains("/api/DramaList/Episode/")) {
                            val kkey = request.url.getQueryParameter("kkey")
                            if (!kkey.isNullOrEmpty()) {
                                streamKey = kkey
                                Log.d("KkeyExtractor", "Found stream kkey: $kkey")
                            }
                        } else if (url.contains("/api/Sub/")) {
                            val kkey = request.url.getQueryParameter("kkey")
                            if (!kkey.isNullOrEmpty()) {
                                subKey = kkey
                                Log.d("KkeyExtractor", "Found sub kkey: $kkey")
                            }
                        }

                        if (streamKey != null && subKey != null) {
                            if (!isCompleted) {
                                isCompleted = true
                                handler.removeCallbacks(timeoutRunnable)
                                handler.post {
                                    webView.stopLoading()
                                    webView.destroy()
                                    result.success(mapOf("streamKkey" to streamKey, "subKkey" to subKey))
                                }
                            }
                        }
                    }
                    return super.shouldInterceptRequest(view, request)
                }
            }

            val targetUrl = "$baseUrl/Drama/a/Episode-1?id=$dramaId&ep=$episodeId"
            Log.d("KkeyExtractor", "Loading URL: $targetUrl")
            webView.loadUrl(targetUrl)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
