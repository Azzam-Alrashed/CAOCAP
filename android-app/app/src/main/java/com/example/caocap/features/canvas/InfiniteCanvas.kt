package com.example.caocap.features.canvas

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import kotlin.math.ceil
import kotlin.math.floor

@Composable
fun InfiniteCanvas(
  modifier: Modifier = Modifier,
  initialScale: Float = 0.3f,
  minScale: Float = 0.1f,
  maxScale: Float = 3.0f,
  dotColor: Color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.2f)
) {
  var scale by remember { mutableFloatStateOf(initialScale) }
  var offsetX by remember { mutableFloatStateOf(0f) }
  var offsetY by remember { mutableFloatStateOf(0f) }

  Canvas(
    modifier = modifier
      .fillMaxSize()
      .background(MaterialTheme.colorScheme.background)
      .pointerInput(Unit) {
        detectTransformGestures { centroid, pan, zoom, _ ->
          val oldScale = scale
          val newScale = (scale * zoom).coerceIn(minScale, maxScale)
          val actualZoom = newScale / oldScale
          
          // Adjust offset so that the canvas zooms around the centroid
          offsetX = centroid.x - (centroid.x - offsetX) * actualZoom
          offsetY = centroid.y - (centroid.y - offsetY) * actualZoom
          
          offsetX += pan.x
          offsetY += pan.y
          scale = newScale
        }
      }
  ) {
    val canvasWidth = size.width
    val canvasHeight = size.height

    // Calculate how many dots to draw based on current scale and translation.
    // The visual spacing between dots scales up and down.
    val baseGridSpacing = 50.dp.toPx()
    val scaledSpacing = baseGridSpacing * scale
    
    val startCol = floor(-offsetX / scaledSpacing).toInt()
    val endCol = ceil((canvasWidth - offsetX) / scaledSpacing).toInt()
    
    val startRow = floor(-offsetY / scaledSpacing).toInt()
    val endRow = ceil((canvasHeight - offsetY) / scaledSpacing).toInt()

    val dotRadius = 2.dp.toPx()

    for (col in startCol..endCol) {
      for (row in startRow..endRow) {
        val cx = col * scaledSpacing + offsetX
        val cy = row * scaledSpacing + offsetY
        drawCircle(
          color = dotColor,
          radius = dotRadius,
          center = Offset(cx, cy)
        )
      }
    }
  }
}
