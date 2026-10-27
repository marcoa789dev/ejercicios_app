plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ejerciciosapp.ejercicios_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // El applicationId real lo define cada flavor (user / admin).
        applicationId = "com.ejerciciosapp.app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Dos apps desde el mismo código:
    //   flutter run --flavor user  -t lib/main_user.dart
    //   flutter run --flavor admin -t lib/main_admin.dart
    flavorDimensions += "app"
    productFlavors {
        create("user") {
            dimension = "app"
            applicationId = "com.ejerciciosapp.app"
            manifestPlaceholders["appName"] = "Ejercicios"
        }
        create("admin") {
            dimension = "app"
            applicationId = "com.ejerciciosapp.admin"
            manifestPlaceholders["appName"] = "Ejercicios Admin"
        }
    }

    buildTypes {
        release {
            // TODO(sprint-5): firmar con la llave propia (android/key.properties).
            // Mientras tanto se firma con la llave de debug para que `flutter run --release` funcione.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
