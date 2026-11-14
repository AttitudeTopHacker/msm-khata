package com.msmmovin.msmkhata_app

import android.os.Build
import androidx.annotation.NonNull
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.msmmovin.msmkhata/biometric"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canAuthenticate" -> {
                    val biometricManager = BiometricManager.from(this)
                    val authenticators = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.BIOMETRIC_WEAK or BiometricManager.Authenticators.DEVICE_CREDENTIAL
                    } else {
                        BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.BIOMETRIC_WEAK
                    }
                    val canAuth = biometricManager.canAuthenticate(authenticators)
                    result.success(canAuth == BiometricManager.BIOMETRIC_SUCCESS)
                }
                "authenticate" -> {
                    val title = call.argument<String>("title") ?: "MsmKhata Unlock"
                    val subtitle = call.argument<String>("subtitle") ?: "Fingerprint scan karein app unlock karne ke liye"
                    val negativeButton = call.argument<String>("negativeButton") ?: "PIN Use Karein"

                    val executor: Executor = ContextCompat.getMainExecutor(this)
                    var hasResponded = false

                    val promptInfo = BiometricPrompt.PromptInfo.Builder()
                        .setTitle(title)
                        .setSubtitle(subtitle)
                        .setNegativeButtonText(negativeButton)
                        .setConfirmationRequired(false)
                        .build()

                    val biometricPrompt = BiometricPrompt(this, executor, object : BiometricPrompt.AuthenticationCallback() {
                        override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                            super.onAuthenticationSucceeded(authResult)
                            if (!hasResponded) {
                                hasResponded = true
                                result.success(true)
                            }
                        }

                        override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                            super.onAuthenticationError(errorCode, errString)
                            if (!hasResponded) {
                                hasResponded = true
                                result.success(false)
                            }
                        }

                        override fun onAuthenticationFailed() {
                            super.onAuthenticationFailed()
                            // User can retry touching fingerprint sensor
                        }
                    })

                    try {
                        biometricPrompt.authenticate(promptInfo)
                    } catch (e: Exception) {
                        if (!hasResponded) {
                            hasResponded = true
                            result.error("BIOMETRIC_ERROR", e.localizedMessage, null)
                        }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
