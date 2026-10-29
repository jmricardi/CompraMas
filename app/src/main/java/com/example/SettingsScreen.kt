package com.example

import com.example.components.AppHeaderTopBar
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@Composable
fun SettingsScreen() {
    val context = LocalContext.current
    val configuration = LocalConfiguration.current
    val isTabletOrDesktop = configuration.screenWidthDp >= 700

    // States for toggles
    var helpExpanded by remember { mutableStateOf(false) }
    var legalExpanded by remember { mutableStateOf(false) }

    // Locale selection state
    var languageMenuExpanded by remember { mutableStateOf(false) }
    var selectedLanguage by remember { mutableStateOf("Español") }
    val languages = listOf("Español" to "es", "English" to "en", "Português" to "pt", "Avañe'ẽ" to "gn")

    val column1 = @Composable {
        // 1. Limpiar Caché
        GlassCard(onClick = {
            Toast.makeText(context, "Caché limpiada", Toast.LENGTH_SHORT).show()
        }) {
            ActionRow(
                title = "Limpiar caché",
                icon = Icons.Default.CleaningServices
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        // 3. Anuncios Vistos Hoy (Simulado)
        GlassCard(onClick = {
            Toast.makeText(context, "Mostrando anuncio...", Toast.LENGTH_SHORT).show()
        }) {
            ActionRow(
                title = "Anuncios vistos hoy",
                subtitle = "Toca para ver anuncio",
                icon = Icons.Default.Stars,
                trailing = { Text("3 / 5", fontWeight = FontWeight.Bold) }
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        // 4. Selector de Idioma
        Box {
            GlassCard(onClick = { languageMenuExpanded = true }) {
                ActionRow(
                    title = "Idioma",
                    subtitle = selectedLanguage,
                    icon = Icons.Default.Language,
                    trailing = { Icon(Icons.Default.ArrowDropDown, contentDescription = null) }
                )
            }
            DropdownMenu(
                expanded = languageMenuExpanded,
                onDismissRequest = { languageMenuExpanded = false }
            ) {
                languages.forEach { (name, code) ->
                    DropdownMenuItem(
                        text = { Text(name) },
                        onClick = {
                            selectedLanguage = name
                            languageMenuExpanded = false
                            Toast.makeText(context, "Idioma cambiado a $code", Toast.LENGTH_SHORT).show()
                        },
                        trailingIcon = if (selectedLanguage == name) {
                            { Icon(Icons.Default.Check, contentDescription = null, tint = Color.Yellow) }
                        } else null
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // 5. Ayuda (Expandable)
        ExpandableCard(
            title = "Ayuda",
            icon = Icons.Outlined.HelpOutline,
            expanded = helpExpanded,
            onExpandChange = { helpExpanded = it }
        ) {
            ActionRow(
                title = "Ver Tutoriales",
                icon = Icons.Default.PlayCircle,
                onClick = { openUrl(context, "https://youtube.com") }
            )
            ActionRow(
                title = "FAQ",
                icon = Icons.Default.Quiz,
                onClick = { openUrl(context, "https://prisma.arandulabs.dev/faq.html") }
            )
        }
    }

    val column2 = @Composable {
        // 1. Calificar
        GlassCard(onClick = { openUrl(context, "market://details?id=dev.arandulabs.prisma") }) {
            ActionRow(
                title = "Calificar aplicación",
                icon = Icons.Default.StarRate,
                iconTint = Color(0xFF00E676),
                titleColor = Color(0xFF00E676)
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        // 2. Compartir
        GlassCard(onClick = {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, "¡Prueba esta app! https://play.google.com/store/apps/details?id=dev.arandulabs.prisma")
            }
            context.startActivity(Intent.createChooser(intent, "Compartir aplicación"))
        }) {
            ActionRow(
                title = "Compartir aplicación",
                icon = Icons.Default.Share,
                iconTint = Color(0xFF00E676),
                titleColor = Color(0xFF00E676)
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        // 3. Legal e Información
        ExpandableCard(
            title = "Legal e Información",
            icon = Icons.Default.Gavel,
            expanded = legalExpanded,
            onExpandChange = { legalExpanded = it }
        ) {
            ActionRow(
                title = "Términos de Uso",
                icon = Icons.Outlined.Description,
                onClick = { openUrl(context, "https://prisma.arandulabs.dev/terms.html") }
            )
            ActionRow(
                title = "Política de Privacidad",
                icon = Icons.Outlined.PrivacyTip,
                onClick = { openUrl(context, "https://prisma.arandulabs.dev/privacy.html") }
            )
            ActionRow(
                title = "Web del Desarrollador",
                icon = Icons.Default.Language,
                onClick = { openUrl(context, "https://arandulabs.dev/es/") }
            )
            ActionRow(
                title = "Versión de la App",
                subtitle = "v1.0.1 (17)",
                icon = Icons.Outlined.Info,
                onClick = {}
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        // 4. Salir
        GlassCard(onClick = { (context as? Activity)?.finish() }) {
            ActionRow(
                title = "Salir de la aplicación",
                icon = Icons.Default.ExitToApp,
                iconTint = MaterialTheme.colorScheme.error,
                titleColor = MaterialTheme.colorScheme.error,
                titleWeight = FontWeight.Bold
            )
        }
    }

    Scaffold(
        topBar = {
            AppHeaderTopBar("Ajustes")
        }
    ) { padding ->
        if (isTabletOrDesktop) {
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(24.dp),
                horizontalArrangement = Arrangement.spacedBy(24.dp)
            ) {
                Column(modifier = Modifier.weight(1f).verticalScroll(rememberScrollState())) {
                    column1()
                }
                Column(modifier = Modifier.weight(1f).verticalScroll(rememberScrollState())) {
                    column2()
                }
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(16.dp)
                    .verticalScroll(rememberScrollState())
            ) {
                column1()
                Spacer(modifier = Modifier.height(16.dp))
                column2()
            }
        }
    }
}

@Composable
fun ExpandableCard(
    title: String,
    icon: ImageVector,
    expanded: Boolean,
    onExpandChange: (Boolean) -> Unit,
    content: @Composable ColumnScope.() -> Unit
) {
    val rotation by animateFloatAsState(targetValue = if (expanded) 180f else 0f, label = "rotation")

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f))
    ) {
        Column {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onExpandChange(!expanded) }
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(icon, contentDescription = null)
                Spacer(modifier = Modifier.width(16.dp))
                Text(title, modifier = Modifier.weight(1f), fontWeight = FontWeight.Bold)
                Icon(
                    Icons.Default.ExpandMore,
                    contentDescription = null,
                    modifier = Modifier.rotate(rotation)
                )
            }
            AnimatedVisibility(visible = expanded) {
                Column(modifier = Modifier.padding(bottom = 8.dp)) {
                    content()
                }
            }
        }
    }
}

@Composable
fun GlassCard(
    onClick: (() -> Unit)? = null,
    content: @Composable () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f))
    ) {
        content()
    }
}

@Composable
fun ActionRow(
    title: String,
    subtitle: String? = null,
    icon: ImageVector,
    iconTint: Color = LocalContentColor.current,
    titleColor: Color = Color.Unspecified,
    titleWeight: FontWeight = FontWeight.Normal,
    trailing: @Composable (() -> Unit)? = null,
    onClick: (() -> Unit)? = null
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, contentDescription = null, tint = iconTint)
        Spacer(modifier = Modifier.width(16.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, color = titleColor, fontWeight = titleWeight)
            if (subtitle != null) {
                Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        if (trailing != null) {
            Spacer(modifier = Modifier.width(16.dp))
            trailing()
        }
    }
}

fun openUrl(context: Context, url: String) {
    try {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        context.startActivity(intent)
    } catch (e: Exception) {
        Toast.makeText(context, "No se pudo abrir el enlace", Toast.LENGTH_SHORT).show()
    }
}
