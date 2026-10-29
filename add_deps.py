import re

with open("app/build.gradle.kts", "r") as f:
    build_gradle = f.read()

if "libs.maps.compose" not in build_gradle:
    build_gradle = build_gradle.replace("implementation(libs.retrofit)", "implementation(libs.retrofit)\n  implementation(libs.maps.compose)\n  implementation(libs.play.services.maps)")

with open("app/build.gradle.kts", "w") as f:
    f.write(build_gradle)
