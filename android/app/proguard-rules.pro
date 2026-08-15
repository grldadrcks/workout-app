# LifeFitness BLE SDK (lfopen2.aar) uses EasyFlow state machine at compile time only
-dontwarn au.com.ds.ef.EasyFlow
-dontwarn au.com.ds.ef.EventEnum
-dontwarn au.com.ds.ef.FlowBuilder$ToHolder
-dontwarn au.com.ds.ef.FlowBuilder
-dontwarn au.com.ds.ef.StateEnum
-dontwarn au.com.ds.ef.StatefulContext
-dontwarn au.com.ds.ef.Transition
-dontwarn au.com.ds.ef.call.ContextHandler
-dontwarn au.com.ds.ef.err.LogicViolationError
-dontwarn com.google.common.eventbus.EventBus

# OkHttp optional SSL providers (Conscrypt, OpenJSSE) — not used on Android
-dontwarn org.conscrypt.Conscrypt$Version
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.ConscryptHostnameVerifier
-dontwarn org.openjsse.javax.net.ssl.SSLParameters
-dontwarn org.openjsse.javax.net.ssl.SSLSocket
-dontwarn org.openjsse.net.ssl.OpenJSSE
