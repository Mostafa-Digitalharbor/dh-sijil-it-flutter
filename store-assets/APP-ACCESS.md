# App content — Login details (تفاصيل تسجيل الدخول)

Play's "any other information required to access your app" field. Max 500
characters, English only. Replace `YOUR-SERVER` and `YOUR-DB` with the demo
Odoo instance the reviewers should use, then paste.

Name: Admin Account In Sijil It
Username: admin
Password: (the demo account's password)

## Other information

    This app is an Odoo client, so it asks for a server before the sign-in details.
    
    On first launch, on the Connection screen:
    1. Server URL: https://YOUR-SERVER
    2. Tap "Detect databases" and pick YOUR-DB, or type it in the Database field.
    3. Tap "Test connection", then "Continue".
    4. Sign in with the username and password above.
    
    The app then opens on the Dashboard. No 2FA or OTP. App lock is off by default. Camera and microphone are optional (QR scanning, voice search).

## Keep this true

- The instance must stay reachable for the whole review, and for every future
  update review -- Play re-uses this declaration each time.
- Point it at a dedicated demo database with sample data, never production:
  these credentials are admin-level and are typed into a Google form.
- The reviewer never needs the camera, the microphone or a biometric prompt.
  App lock defaults to off (`appPreferences.appLockEnabled` -> false).
