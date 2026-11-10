#!/usr/bin/env python3
"""Idempotent patches for the generated android/ and ios/ folders."""
import pathlib
import re

SCHEME = "io.supabase.zhentropic"


def patch_android():
    p = pathlib.Path("android/app/src/main/AndroidManifest.xml")
    if not p.exists():
        return
    s = p.read_text(encoding="utf-8")
    if SCHEME in s:
        print("android: already patched")
        return

    perms = "".join(
        f'    <uses-permission android:name="android.permission.{n}"/>\n'
        for n in ("INTERNET", "CAMERA", "RECORD_AUDIO")
    )
    s = s.replace("<application", perms + "    <application", 1)

    extra_queries = """        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="mailto"/></intent>
        <intent><action android:name="android.speech.RecognitionService"/></intent>
        <intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>
"""
    if "</queries>" in s:
        s = s.replace("</queries>", extra_queries + "    </queries>", 1)
    else:
        s = s.replace("</manifest>", "    <queries>\n" + extra_queries + "    </queries>\n</manifest>", 1)

    deep_link = f"""            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="{SCHEME}" android:host="login-callback"/>
            </intent-filter>
"""
    s = s.replace("</activity>", deep_link + "        </activity>", 1)
    s = re.sub(r'android:label="[^"]*"', 'android:label="Zhentropic"', s, count=1)
    p.write_text(s, encoding="utf-8")
    print("android: patched")


def patch_ios():
    p = pathlib.Path("ios/Runner/Info.plist")
    if p.exists():
        s = p.read_text(encoding="utf-8")
        if SCHEME not in s:
            add = f"""	<key>NSCameraUsageDescription</key>
	<string>Zhentropic uses the camera so you can attach photos to your questions.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>Zhentropic lets you attach images from your library.</string>
	<key>NSMicrophoneUsageDescription</key>
	<string>Zhentropic uses the microphone for voice input.</string>
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>Zhentropic turns your speech into text.</string>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>{SCHEME}</string>
			</array>
		</dict>
	</array>
	<key>LSApplicationQueriesSchemes</key>
	<array>
		<string>https</string>
		<string>mailto</string>
	</array>
"""
            i = s.rfind("</dict>")
            s = s[:i] + add + s[i:]
            s = re.sub(
                r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)",
                r"\g<1>Zhentropic\g<2>",
                s,
            )
            p.write_text(s, encoding="utf-8")
            print("ios: Info.plist patched")

    podfile = pathlib.Path("ios/Podfile")
    if podfile.exists():
        t = podfile.read_text(encoding="utf-8")
        t = re.sub(r"^\s*#?\s*platform :ios,\s*'[\d.]+'", "platform :ios, '13.0'", t, count=1, flags=re.M)
        podfile.write_text(t, encoding="utf-8")


patch_android()
patch_ios()
