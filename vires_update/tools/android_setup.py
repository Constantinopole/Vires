"""Prepares the Android project that `flutter create` made for Vires:
   - app name and icon
   - the 5 switchable launcher icons (activity aliases)
   - the Kotlin code that switches them
   - assets entry in pubspec.yaml
Usage: python3 android_setup.py <flutter project folder>"""
import pathlib
import re
import sys

proj = pathlib.Path(sys.argv[1])
ICONS = ["Shield", "David", "Michael", "Crusader", "Lion"]

# the app's package name
gradle = ""
for g in ("android/app/build.gradle.kts", "android/app/build.gradle"):
    p = proj / g
    if p.exists():
        gradle = p.read_text()
        break
m = re.search(r'namespace\s*=?\s*["\']([\w.]+)["\']', gradle)
ns = m.group(1) if m else "com.vires.gym_log"
print("package:", ns)

# ---- manifest ----
mp = proj / "android/app/src/main/AndroidManifest.xml"
t = mp.read_text()
t = re.sub(r'android:label="[^"]*"', 'android:label="Vires"', t, count=1)
assert 'android:icon="@mipmap/ic_launcher"' in t, "app icon line not found"
t = t.replace('android:icon="@mipmap/ic_launcher"', 'android:icon="@mipmap/ic_shield"')
launcher = re.compile(
    r'<intent-filter>\s*<action android:name="android.intent.action.MAIN"\s*/>\s*'
    r'<category android:name="android.intent.category.LAUNCHER"\s*/>\s*</intent-filter>')
t, n = launcher.subn("", t, count=1)
assert n == 1, "launcher intent-filter not found"
aliases = ""
for name in ICONS:
    on = "true" if name == "Shield" else "false"
    aliases += f"""
        <activity-alias
            android:name="{ns}.Icon{name}"
            android:enabled="{on}"
            android:exported="true"
            android:icon="@mipmap/ic_{name.lower()}"
            android:label="Vires"
            android:targetActivity="{ns}.MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity-alias>"""
assert "</activity>" in t
t = t.replace("</activity>", "</activity>" + aliases, 1)
mp.write_text(t)

# ---- Kotlin: lets the app switch its own icon ----
KOTLIN = """package __NS__

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val names = listOf("Shield", "David", "Michael", "Crusader", "Lion")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vires/icon").setMethodCallHandler { call, result ->
            when (call.method) {
                "get" -> result.success(current())
                "set" -> {
                    val name = call.argument<String>("name")
                    if (name != null && names.contains(name)) {
                        select(name)
                        result.success(null)
                    } else {
                        result.error("bad_name", "Unknown icon", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun component(name: String) = ComponentName(packageName, "__NS__.Icon" + name)

    private fun isOn(name: String): Boolean {
        return when (packageManager.getComponentEnabledSetting(component(name))) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> false
            else -> name == "Shield"
        }
    }

    private fun current(): String = names.firstOrNull { isOn(it) } ?: "Shield"

    private fun select(name: String) {
        packageManager.setComponentEnabledSetting(
            component(name), PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
        for (other in names) {
            if (other != name) {
                packageManager.setComponentEnabledSetting(
                    component(other), PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
            }
        }
    }
}
"""
srcdir = proj / "android/app/src/main"
for f in list(srcdir.rglob("MainActivity.*")):
    f.unlink()
kt = srcdir / "kotlin" / pathlib.Path(*ns.split(".")) / "MainActivity.kt"
kt.parent.mkdir(parents=True, exist_ok=True)
kt.write_text(KOTLIN.replace("__NS__", ns))

# ---- pubspec: register the pictures and sounds ----
pp = proj / "pubspec.yaml"
y = pp.read_text()
y, n = re.subn(r'^(\s*)uses-material-design:\s*true\s*$',
               r'\1uses-material-design: true\n\1assets:\n\1  - assets/icon/\n\1  - assets/sounds/',
               y, count=1, flags=re.M)
assert n == 1, "uses-material-design line not found in pubspec.yaml"
pp.write_text(y)
print("android setup done")
