@echo off
set JAVA_HOME=H:\jdk17
set ANDROID_HOME=H:\AndroidSDK
cd /d "H:\Claude\Mobile-prices\app"
"H:\FlutterSDK\bin\flutter.bat" build apk --debug --dart-define-from-file=env/dev.json
echo APK: app\build\app\outputs\flutter-apk\app-debug.apk
