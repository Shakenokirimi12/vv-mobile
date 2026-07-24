plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
    `maven-publish`
}

android {
    namespace = "jp.voicevox.android"
    compileSdk = 35

    defaultConfig {
        minSdk = 26
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("consumer-rules.pro")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    publishing {
        singleVariant("release") {
            withSourcesJar()
        }
    }
}

dependencies {
    // 公式 Java API(JNIブリッジ内蔵、local-maven から解決)
    api("jp.hiroshiba.voicevoxcore:voicevoxcore-android:0.16.4")

    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")

    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
}

publishing {
    publications {
        register<MavenPublication>("release") {
            groupId = "jp.voicevox"
            artifactId = "voicevox-core-android"
            // JitPack はタグ名を VERSION 環境変数として渡す。
            // 例: タグ android-v0.1.0 → 生成される artifact も同名バージョンに揃うため
            // 利用者は `com.github.Shakenokirimi12:vv-mobile:android-v0.1.0` で解決できる。
            version = System.getenv("VERSION") ?: "0.1.0"
            afterEvaluate {
                from(components["release"])
            }
        }
    }
}
