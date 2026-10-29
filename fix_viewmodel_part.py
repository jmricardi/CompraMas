import re

with open("app/src/main/java/com/example/viewmodel/ScannerViewModel.kt", "r") as f:
    content = f.read()

content = content.replace("import com.example.network.Part", "import com.example.network.GeminiPart")
content = content.replace("listOf(Part(text", "listOf(GeminiPart(text")
content = content.replace("?.parts?.firstOrNull()?.text", "?.parts?.firstOrNull()?.text")

with open("app/src/main/java/com/example/viewmodel/ScannerViewModel.kt", "w") as f:
    f.write(content)
