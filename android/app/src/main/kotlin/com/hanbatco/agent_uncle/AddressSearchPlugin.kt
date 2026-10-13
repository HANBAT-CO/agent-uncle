package com.hanbatco.agent_uncle

import android.annotation.SuppressLint
import android.app.Dialog
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.view.ViewGroup
import android.webkit.ConsoleMessage
import android.webkit.JavascriptInterface
import android.webkit.JsResult
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONException
import org.json.JSONObject

class AddressSearchPlugin(
    messenger: BinaryMessenger,
    private val activity: FragmentActivity,
) : MethodChannel.MethodCallHandler, DefaultLifecycleObserver {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    private var disposed = false
    private var sessionSerial = 0L
    private var activeSessionId: Long? = null
    private var pendingResult: MethodChannel.Result? = null
    private var activeDialog: AddressSearchDialog? = null

    init {
        channel.setMethodCallHandler(this)
        activity.lifecycle.addObserver(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "searchKakaoPostcode" -> {
                activity.runOnUiThread {
                    startSearch(result)
                }
            }
            "cancelSearch" -> {
                activity.runOnUiThread {
                    activeDialog?.cancelByHost()
                    result.success(null)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDestroy(owner: LifecycleOwner) {
        dispose()
    }

    fun dispose() {
        if (disposed) return
        activity.lifecycle.removeObserver(this)
        channel.setMethodCallHandler(null)
        activity.runOnUiThread {
            activeDialog?.dismissSilently()
            completeActiveSessionWithNull()
            disposed = true
        }
    }

    private fun startSearch(result: MethodChannel.Result) {
        if (disposed || activity.isFinishing || activity.isDestroyed) {
            result.error("unavailable", "주소 검색을 열지 못했어요. 다시 시도해 주세요.", null)
            return
        }
        if (pendingResult != null) {
            result.error("busy", "주소 검색이 이미 진행 중이에요. 잠시 후 다시 시도해 주세요.", null)
            return
        }

        sessionSerial += 1
        val sessionId = sessionSerial
        activeSessionId = sessionId
        pendingResult = result
        activeDialog = AddressSearchDialog(
            activity = activity,
            sessionId = sessionId,
            onSelected = ::handleSelected,
            onCancelled = ::handleCancelled,
            onError = ::handleError,
        )
        try {
            activeDialog?.show()
        } catch (error: Exception) {
            clearSessionState()
            result.error(
                "unavailable",
                error.message ?: "주소 검색을 열지 못했어요. 다시 시도해 주세요.",
                null,
            )
        }
    }

    private fun handleSelected(sessionId: Long, payload: Map<String, Any?>) {
        activity.runOnUiThread {
            if (!isActiveSession(sessionId)) return@runOnUiThread
            pendingResult?.success(payload)
            clearSessionState()
        }
    }

    private fun handleCancelled(sessionId: Long) {
        activity.runOnUiThread {
            if (!isActiveSession(sessionId)) return@runOnUiThread
            pendingResult?.success(null)
            clearSessionState()
        }
    }

    private fun handleError(sessionId: Long, code: String, message: String) {
        activity.runOnUiThread {
            if (!isActiveSession(sessionId)) return@runOnUiThread
            pendingResult?.error(code, message, null)
            clearSessionState()
        }
    }

    private fun completeActiveSessionWithNull() {
        val sessionId = activeSessionId ?: return
        if (!isActiveSession(sessionId)) return
        pendingResult?.success(null)
        clearSessionState()
    }

    private fun isActiveSession(sessionId: Long): Boolean =
        activeSessionId == sessionId && pendingResult != null

    private fun clearSessionState() {
        activeDialog = null
        activeSessionId = null
        pendingResult = null
    }

    companion object {
        const val CHANNEL_NAME = "agent_uncle/address_search"
    }
}

@SuppressLint("SetJavaScriptEnabled")
private class AddressSearchDialog(
    activity: FragmentActivity,
    private val sessionId: Long,
    private val onSelected: (Long, Map<String, Any?>) -> Unit,
    private val onCancelled: (Long) -> Unit,
    private val onError: (Long, String, String) -> Unit,
) : Dialog(activity) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val bridge = Bridge(
        mainHandler = mainHandler,
        sessionId = sessionId,
        onSelected = ::finishWithPayload,
        onCancelled = ::finishCancelled,
        onError = ::finishError,
        onScriptLoaded = ::clearLoadTimeout,
    )

    private var completed = false
    private var destroyed = false
    private lateinit var webView: WebView
    private val loadTimeoutRunnable = Runnable {
        finishError("unavailable", "주소 검색 화면을 불러오지 못했어요. 다시 시도해 주세요.")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setCancelable(true)
        setCanceledOnTouchOutside(true)

        webView = WebView(context)
        setContentView(webView)
        webView.setBackgroundColor(Color.WHITE)
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            cacheMode = WebSettings.LOAD_NO_CACHE
            javaScriptCanOpenWindowsAutomatically = false
            allowFileAccess = false
            allowContentAccess = false
            setSupportMultipleWindows(false)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            }
        }
        webView.addJavascriptInterface(bridge, BRIDGE_NAME)
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(
                view: WebView,
                request: WebResourceRequest,
            ): Boolean = !isAllowedNavigation(request.url)

            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: WebResourceError,
            ) {
                if (!request.isForMainFrame) return
                finishError("unavailable", "네트워크 상태를 확인한 뒤 다시 시도해 주세요.")
            }
        }
        webView.webChromeClient = object : WebChromeClient() {
            override fun onJsAlert(
                view: WebView,
                url: String,
                message: String,
                jsResult: JsResult,
            ): Boolean {
                jsResult.confirm()
                return true
            }

            override fun onCreateWindow(
                view: WebView,
                isDialog: Boolean,
                isUserGesture: Boolean,
                resultMsg: Message,
            ): Boolean = false

            override fun onConsoleMessage(consoleMessage: ConsoleMessage): Boolean = false
        }
        setOnCancelListener {
            finishCancelled()
        }
        scheduleLoadTimeout()
        webView.loadDataWithBaseURL(
            BASE_URL,
            POSTCODE_HTML,
            "text/html",
            "utf-8",
            null,
        )
    }

    override fun onStart() {
        super.onStart()
        window?.setLayout(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
    }

    override fun dismiss() {
        if (destroyed) {
            super.dismiss()
            return
        }
        destroyed = true
        clearLoadTimeout()
        if (::webView.isInitialized) {
            webView.stopLoading()
            webView.removeJavascriptInterface(BRIDGE_NAME)
            webView.webChromeClient = null
            webView.webViewClient = object : WebViewClient() {}
            webView.destroy()
        }
        super.dismiss()
    }

    fun cancelByHost() {
        finishCancelled()
    }

    fun dismissSilently() {
        completed = true
        dismiss()
    }

    private fun scheduleLoadTimeout() {
        clearLoadTimeout()
        mainHandler.postDelayed(loadTimeoutRunnable, LOAD_TIMEOUT_MS)
    }

    private fun clearLoadTimeout() {
        mainHandler.removeCallbacks(loadTimeoutRunnable)
    }

    private fun finishCancelled() {
        if (completed) return
        completed = true
        clearLoadTimeout()
        onCancelled(sessionId)
        dismiss()
    }

    private fun finishError(code: String, message: String) {
        if (completed) return
        completed = true
        clearLoadTimeout()
        onError(sessionId, code, message)
        dismiss()
    }

    private fun finishWithPayload(payload: Map<String, Any?>) {
        if (completed) return
        completed = true
        clearLoadTimeout()
        onSelected(sessionId, payload)
        dismiss()
    }

    private fun isAllowedNavigation(uri: Uri): Boolean {
        if (uri.scheme == "about" && uri.toString() == "about:blank") return true
        if (uri.scheme != "https") return false
        return uri.host in ALLOWED_HOSTS
    }

    private class Bridge(
        private val mainHandler: Handler,
        private val sessionId: Long,
        private val onSelected: (Map<String, Any?>) -> Unit,
        private val onCancelled: () -> Unit,
        private val onError: (String, String) -> Unit,
        private val onScriptLoaded: () -> Unit,
    ) {
        @JavascriptInterface
        fun postMessage(value: String) {
            mainHandler.post {
                val payload = try {
                    parsePayload(value)
                } catch (_: JSONException) {
                    onError("unavailable", "주소 검색 결과를 확인하지 못했어요. 다시 시도해 주세요.")
                    return@post
                }
                onSelected(payload)
            }
        }

        @JavascriptInterface
        fun cancel() {
            mainHandler.post {
                onCancelled()
            }
        }

        @JavascriptInterface
        fun onScriptLoaded() {
            mainHandler.post {
                onScriptLoaded.invoke()
            }
        }

        @JavascriptInterface
        fun onScriptLoadFailed() {
            mainHandler.post {
                onError("unavailable", "주소 검색 화면을 불러오지 못했어요. 다시 시도해 주세요.")
            }
        }

        private fun parsePayload(value: String): Map<String, Any?> {
            val json = JSONObject(value)
            val postcode = json.optString("zonecode").trim()
            val roadAddress = json.optString("roadAddress").trim()
            val jibunAddress = json.optString("jibunAddress").trim()
            val buildingName = json.optString("buildingName").trim()
            if (!Regex("[0-9]{5}").matches(postcode) ||
                (roadAddress.isEmpty() && jibunAddress.isEmpty())) {
                throw JSONException("invalid_payload_$sessionId")
            }
            return mapOf(
                "postcode" to postcode,
                "roadAddress" to roadAddress,
                "jibunAddress" to jibunAddress,
                "buildingName" to buildingName,
                "source" to "kakao_postcode",
            )
        }
    }

    companion object {
        private const val BRIDGE_NAME = "AgentUncleAddressSearch"
        private const val BASE_URL = "https://postcode.map.kakao.com/"
        private const val LOAD_TIMEOUT_MS = 15_000L
        private val ALLOWED_HOSTS = setOf(
            "postcode.map.kakao.com",
            "postcode.map.daum.net",
            "t1.daumcdn.net",
            "t1.kakaocdn.net",
        )
    }
}

private const val POSTCODE_HTML = """
<!DOCTYPE html>
<html lang="ko">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
    <style>
      html, body, #wrap { margin: 0; padding: 0; width: 100%; height: 100%; background: #ffffff; }
      #wrap { min-height: 100%; }
    </style>
    <script>
      var __agentUncleSdkLoaded = false;
      var __agentUncleOpened = false;

      function notifySdkLoaded() {
        __agentUncleSdkLoaded = true;
        maybeOpenPostcode();
      }

      function notifySdkLoadFailed() {
        window.AgentUncleAddressSearch.onScriptLoadFailed();
      }

      function maybeOpenPostcode() {
        var wrap = document.getElementById('wrap');
        if (__agentUncleOpened || !__agentUncleSdkLoaded || !wrap) {
          return;
        }
        var Postcode = window.kakao && window.kakao.Postcode;
        if (!Postcode && window.daum) Postcode = window.daum.Postcode;
        if (!Postcode) {
          notifySdkLoadFailed();
          return;
        }
        __agentUncleOpened = true;
        try {
          var observer = new MutationObserver(function() {
            var iframe = wrap.querySelector('iframe');
            if (!iframe) return;
            observer.disconnect();
            iframe.addEventListener('load', function() {
              window.AgentUncleAddressSearch.onScriptLoaded();
            }, { once: true });
          });
          observer.observe(wrap, { childList: true, subtree: true });
          new Postcode({
            oncomplete: function(data) {
              window.AgentUncleAddressSearch.postMessage(JSON.stringify({
                zonecode: data.zonecode || '',
                roadAddress: data.roadAddress || '',
                jibunAddress: data.jibunAddress || '',
                buildingName: data.buildingName || ''
              }));
            },
            onclose: function(state) {
              if (state === 'FORCE_CLOSE') {
                window.AgentUncleAddressSearch.cancel();
              }
            },
            width: '100%',
            height: '100%'
          }).embed(wrap);
        } catch (error) {
          window.AgentUncleAddressSearch.onScriptLoadFailed();
        }
      }

      window.addEventListener('load', maybeOpenPostcode);
    </script>
    <script
      src="https://t1.kakaocdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js"
      onload="notifySdkLoaded()"
      onerror="notifySdkLoadFailed()"></script>
  </head>
  <body>
    <div id="wrap"></div>
  </body>
</html>
"""
