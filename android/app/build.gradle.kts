plugins {
    id("com.android.application")
    id("kotlin-android")
    // O plugin Flutter deve ser aplicado depois dos plugins Android e Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // plugin do Google Services para Firebase
}

android {
    namespace = "com.example.gestao_leitores"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // Definindo explicitamente a versão do NDK

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.gestao_leitores"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Configuração de assinatura para o release (aqui está com debug temporariamente)
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

