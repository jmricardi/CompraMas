import re

with open("app/src/main/java/com/example/MainActivity.kt", "r") as f:
    content = f.read()

content = content.replace('composable("fuel") { PlaceholderScreen("Combustible en Mapa") }', 'composable("fuel") { com.example.screens.FuelMapScreen() }')

with open("app/src/main/java/com/example/MainActivity.kt", "w") as f:
    f.write(content)

