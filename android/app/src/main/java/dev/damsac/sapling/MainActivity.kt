package dev.damsac.sapling

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.damsac.sapling.rust.*

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize Sapling with a database in the app's files directory
        val dbPath = filesDir.resolve("sapling.db").absolutePath

        setContent {
            MaterialTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background,
                ) {
                    SaplingScreen(dbPath)
                }
            }
        }
    }
}

@Composable
fun SaplingScreen(dbPath: String) {
    val core = remember { SaplingCore(dbPath) }
    var statusText by remember { mutableStateOf("Ready") }
    var seedCount by remember { mutableIntStateOf(0) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = "Sapling",
            style = MaterialTheme.typography.headlineLarge,
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Trail companion powered by Rust",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Spacer(modifier = Modifier.height(32.dp))

        Text(
            text = "Seeds created: $seedCount",
            style = MaterialTheme.typography.titleMedium,
        )

        Spacer(modifier = Modifier.height(16.dp))

        Button(onClick = {
            try {
                val seed = core.createSeed(
                    FfiCreateSeedInput(
                        seedType = FfiSeedType.BEAUTY,
                        title = "Test Beauty Spot #${seedCount + 1}",
                        notes = "Created from Android",
                        latitude = 37.7749,
                        longitude = -122.4194,
                        elevation = 100.0,
                        confidence = 90u.toUByte(),
                        tags = listOf("test", "android"),
                    )
                )
                seedCount++
                statusText = "Created seed: ${seed.title}"
            } catch (e: Exception) {
                statusText = "Error: ${e.message}"
            }
        }) {
            Text("Create Test Seed")
        }

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = statusText,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
