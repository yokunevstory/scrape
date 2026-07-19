@echo off
cd /d "H:\Claude\Mobile-prices\app"
"H:\FlutterSDK\bin\flutter.bat" build web --release --dart-define-from-file=env/dev.json
