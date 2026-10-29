import re

with open("gradle/libs.versions.toml", "r") as f:
    toml = f.read()

if "mapsCompose" not in toml:
    toml = toml.replace("[versions]", "[versions]\nmapsCompose = \"6.1.2\"\nplayServicesMaps = \"19.0.0\"")
    toml = toml.replace("[libraries]", "[libraries]\nmaps-compose = { group = \"com.google.maps.android\", name = \"maps-compose\", version.ref = \"mapsCompose\" }\nplay-services-maps = { group = \"com.google.android.gms\", name = \"play-services-maps\", version.ref = \"playServicesMaps\" }")

with open("gradle/libs.versions.toml", "w") as f:
    f.write(toml)
