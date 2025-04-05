plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load almahir-key.properties file
val keystorePropertiesFile = rootProject.file("almahir-key.properties")
val keystoreProperties = org.gradle.internal.impldep.org.yaml.snakeyaml.Yaml()
val readProperties = if (keystorePropertiesFile.exists()) {
    java.util.Properties().apply {
        load(java.io.FileInputStream(keystorePropertiesFile))
    }
} else {
    java.util.Properties()
}

android {
    namespace = "fr.almahir"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "fr.almahir"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = readProperties.getProperty("keyAlias")
                keyPassword = readProperties.getProperty("keyPassword")
                storeFile = file(readProperties.getProperty("storeFile"))
                storePassword = readProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Use the signing config if it exists, otherwise fallback to debug
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
