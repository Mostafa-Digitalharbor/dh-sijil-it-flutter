package net.digitalharbor.sijilit

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * A FlutterFragmentActivity rather than a FlutterActivity.
 *
 * Settings -> Require unlock shows AndroidX's BiometricPrompt, which is a
 * fragment and needs a FragmentActivity to attach to. A plain FlutterActivity
 * builds and launches perfectly well and then throws the first time the prompt
 * is shown -- so the failure lands on a user turning the setting on, not on
 * whoever changed this file.
 *
 * Nothing else in the app depends on the fragment host; local_auth is the only
 * plugin that requires it.
 */
class MainActivity : FlutterFragmentActivity()
