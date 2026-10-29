import re

with open("app/src/main/java/com/example/network/Network.kt", "r") as f:
    content = f.read()

content = content.replace("data class Part(", "data class GeminiPart(")
content = content.replace("val parts: List<Part>", "val parts: List<GeminiPart>")

with open("app/src/main/java/com/example/network/Network.kt", "w") as f:
    f.write(content)
