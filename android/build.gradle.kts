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
}
subprojects {
    project.evaluationDependsOn(":app")
}
subprojects {
    val configureSubproject = Action<Project> {
        if (plugins.hasPlugin("com.android.library")) {
            // Fix namespace
            val android = extensions.findByName("android")
            if (android != null) {
                try {
                    val getNamespace = android.javaClass.getMethod("getNamespace")
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    if (getNamespace.invoke(android) == null) {
                        val cleanName = project.name.replace("-", "_").replace(":", ".")
                        setNamespace.invoke(android, "com.autocare.$cleanName")
                    }
                } catch (e: Exception) {
                    // Ignore
                }
                
                // Force compileSdk to 34 to fix lStar missing resource error
                try {
                    val compileSdkMethod = android.javaClass.getMethod("setCompileSdkVersion", Int::class.java)
                    compileSdkMethod.invoke(android, 34)
                } catch (e: Exception) {
                    // Ignore
                }
            }
            
            // Fix manifest package attribute
            val stripManifestPackage = tasks.register("stripManifestPackage") {
                doLast {
                    val manifestFile = file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        var content = manifestFile.readText()
                        if (content.contains("package=\"")) {
                            content = content.replace(Regex("""\bpackage="[^"]*""""), "")
                            manifestFile.writeText(content)
                            logger.lifecycle("Successfully stripped package attribute from ${manifestFile.absolutePath}")
                        }
                    }
                }
            }
            tasks.matching { it.name.contains("Manifest") && it.name != "stripManifestPackage" }.all {
                dependsOn(stripManifestPackage)
            }
        }
    }
    
    if (state.executed) {
        configureSubproject.execute(this)
    } else {
        afterEvaluate {
            configureSubproject.execute(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
