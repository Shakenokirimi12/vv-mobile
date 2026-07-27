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

// 公式 voicevoxcore-android のバージョン(core-native/VERSION と揃えること)。
val voicevoxCoreVersion = "0.16.4"

dependencies {
    // 公式 Java API(JNIブリッジ内蔵、local-maven から解決)
    api("jp.hiroshiba.voicevoxcore:voicevoxcore-android:$voicevoxCoreVersion")

    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")

    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
}

// JitPack はタグ名を VERSION 環境変数として渡す。
val publishVersion: String = System.getenv("VERSION") ?: "0.1.0"

publishing {
    publications {
        register<MavenPublication>("release") {
            groupId = "jp.voicevox"
            artifactId = "voicevox-core-android"
            // 例: タグ android-v0.1.1 → 生成される artifact も同名バージョンに揃うため
            // 利用者は `com.github.Shakenokirimi12:vv-mobile:android-v0.1.1` で解決できる。
            version = publishVersion
            afterEvaluate {
                from(components["release"])
            }
        }

        // --- 公式 AAR の再発行 ---
        // 本ライブラリは jp.hiroshiba.voicevoxcore:voicevoxcore-android に api 依存するが、
        // この公式 AAR は Maven Central 未公開(公式 java_packages.zip 同梱)。
        // JitPack は「ビルド中に見つかったが公開リポジトリに無い依存」を
        // com.github.<user>.<repo>:<artifactId>:<タグ> へ書き換えて POM / module を publish する。
        // ところが書き換え先の成果物自体は、バージョンがタグと一致しない限り JitPack に
        // アップロードされない。android-v0.1.0 ではこれが原因で
        //   com.github.Shakenokirimi12.vv-mobile:voicevoxcore-android:android-v0.1.0
        // が 404 になり、利用者側の依存解決が失敗していた。
        // そこで公式 AAR を「タグと同じバージョン」で併せて発行し、書き換え先の座標を実在させる。
        register<MavenPublication>("vendoredCore") {
            groupId = "jp.hiroshiba.voicevoxcore"
            artifactId = "voicevoxcore-android"
            version = publishVersion
            artifact(
                rootProject.file(
                    "local-maven/jp/hiroshiba/voicevoxcore/voicevoxcore-android/" +
                        "$voicevoxCoreVersion/voicevoxcore-android-$voicevoxCoreVersion.aar"
                )
            ) {
                extension = "aar"
            }
            pom {
                packaging = "aar"
                name.set("voicevoxcore-android")
                description.set(
                    "VOICEVOX CORE official Android AAR $voicevoxCoreVersion, " +
                        "republished so that it can be resolved from a public repository."
                )
                url.set("https://github.com/VOICEVOX/voicevox_core")
                licenses {
                    license {
                        name.set("MIT License")
                        url.set("https://github.com/VOICEVOX/voicevox_core/blob/main/LICENSE")
                    }
                }
                // 公式 POM が宣言している実行時依存(すべて Maven Central にある)。
                withXml {
                    val deps = asNode().appendNode("dependencies")
                    fun dep(group: String, artifact: String, ver: String, scope: String) {
                        deps.appendNode("dependency").apply {
                            appendNode("groupId", group)
                            appendNode("artifactId", artifact)
                            appendNode("version", ver)
                            appendNode("scope", scope)
                        }
                    }
                    dep("org.jetbrains.kotlin", "kotlin-stdlib-jdk8", "1.9.10", "compile")
                    dep("com.google.code.gson", "gson", "2.10.1", "runtime")
                    dep("jakarta.validation", "jakarta.validation-api", "3.0.2", "runtime")
                    dep("jakarta.annotation", "jakarta.annotation-api", "2.1.1", "runtime")
                }
            }
        }
    }
}
