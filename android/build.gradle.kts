allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Some third-party plugins (e.g. photo_manager) pin Java 17 in their own
    // compileOptions but don't set an explicit Kotlin jvmTarget, letting it
    // float to whatever the resolved Kotlin Gradle Plugin version defaults
    // to — which can drift out of sync with the Java target ("Inconsistent
    // JVM Target Compatibility"). Force both to the same value everywhere.
    //
    // Other plugins (e.g. easy_video_editor) go the other way: they pin
    // Java 1.8 via `android.compileOptions` directly. AGP re-reads that DSL
    // value onto the JavaCompile task when it wires up the variant, which
    // happens as part of the *same* afterEvaluate phase — so a plain
    // `tasks.withType<JavaCompile>().configureEach { sourceCompatibility = ... }`
    // can lose that race depending on callback registration order. Overriding
    // `android.compileOptions` itself (the actual source AGP reads from) is
    // the reliable fix, so do that too, for both library and app modules.
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.let { android ->
            android.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
            android.compileOptions.targetCompatibility = JavaVersion.VERSION_17
        }
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

// flutter_stripe's Android plugin (stripe_android) declares the optional Issuing push-provisioning
// library twice, once without `transitive = false`, which drags in Google's
// play-services-tapandpay. That artifact isn't on Google's public Maven, so the release build's
// lint classpath can't resolve it. The plugin only reaches TapAndPay by reflection (and its
// ProGuard rules already -dontwarn it), and we don't use card push provisioning, so leave it out
// of that one plugin, as its own `transitive = false` line intends.
subprojects {
    if (name == "stripe_android") {
        configurations.configureEach {
            exclude(group = "com.google.android.gms", module = "play-services-tapandpay")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
