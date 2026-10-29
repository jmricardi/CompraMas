with open("app/src/main/java/com/example/SettingsScreen.kt", "r") as f:
    c = f.read()

c = c.replace("package com.exampleimport", "package com.example\n\nimport")

with open("app/src/main/java/com/example/SettingsScreen.kt", "w") as f:
    f.write(c)
