pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            val localProperties = file("local.properties")
            if (localProperties.exists()) {
                localProperties.inputStream().use { properties.load(it) }
            }

            val fromLocalProperties = properties.getProperty("flutter.sdk")?.takeIf { it.isNotBlank() }
            val fromEnv = System.getenv("FLUTTER_ROOT")?.takeIf { it.isNotBlank() }
                ?: System.getenv("FLUTTER_HOME")?.takeIf { it.isNotBlank() }

            val resolved = fromLocalProperties ?: fromEnv
            require(resolved != null) {
                """
                Flutter SDK path not found.
                Set `flutter.sdk` in android/local.properties or set the FLUTTER_ROOT environment variable.
                """.trimIndent()
            }
            resolved
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
