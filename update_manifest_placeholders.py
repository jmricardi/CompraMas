import re

with open("app/build.gradle.kts", "r") as f:
    content = f.read()

# Add manifestPlaceholders = mapOf("MAPS_API_KEY" to (System.getenv("MAPS_API_KEY") ?: ""))
# to defaultConfig
if "manifestPlaceholders" not in content:
    replacement = """
    testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    manifestPlaceholders["MAPS_API_KEY"] = System.getenv("MAPS_API_KEY") ?: ""
  }
"""
    content = content.replace('testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"\n  }', replacement)

with open("app/build.gradle.kts", "w") as f:
    f.write(content)
