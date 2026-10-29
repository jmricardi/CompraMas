import re

with open("app/src/main/java/com/example/screens/ScanScreen.kt", "r") as f:
    content = f.read()

imports = """
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
"""

content = content.replace("import androidx.compose.runtime.Composable", "import androidx.compose.runtime.Composable" + imports)

with open("app/src/main/java/com/example/screens/ScanScreen.kt", "w") as f:
    f.write(content)
