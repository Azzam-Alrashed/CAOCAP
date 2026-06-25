package com.example.caocap.features.overlays

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.VectorConverter
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Job
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

enum class CommandAction {
    Undo, Summon, Redo
}

@Composable
fun BoxScope.FloatingCommandButton(
    onTap: () -> Unit,
    onUndo: () -> Unit,
    onSummonCoCaptain: () -> Unit,
    onRedo: () -> Unit,
    canUndo: Boolean = false,
    canRedo: Boolean = false
) {
    val haptic = LocalHapticFeedback.current
    val density = LocalDensity.current
    val coroutineScope = rememberCoroutineScope()

    var isExpanded by remember { mutableStateOf(false) }
    var isDragging by remember { mutableStateOf(false) }
    var activeAction by remember { mutableStateOf<CommandAction?>(null) }
    
    // We will use Animatable for position to allow snapping animations
    val position = remember { Animatable(Offset.Zero, Offset.VectorConverter) }
    var parentSize by remember { mutableStateOf(IntSize.Zero) }
    
    val buttonSizePx = with(density) { 64.dp.toPx() }
    val paddingPx = with(density) { 35.dp.toPx() }

    // Init position to bottom right
    LaunchedEffect(parentSize) {
        if (parentSize != IntSize.Zero && position.value == Offset.Zero) {
            position.snapTo(
                Offset(
                    x = parentSize.width - paddingPx - buttonSizePx / 2,
                    y = parentSize.height - paddingPx - buttonSizePx / 2
                )
            )
        }
    }

    val sproutDirection = remember(position.value, parentSize) {
        if (parentSize == IntSize.Zero) return@remember Offset(0f, -1f)
        val centerX = parentSize.width / 2f
        val centerY = parentSize.height / 2f
        val dx = centerX - position.value.x
        val dy = centerY - position.value.y
        val len = sqrt(dx * dx + dy * dy)
        if (len > 0) Offset(dx / len, dy / len) else Offset(0f, -1f)
    }

    val buttonScale by animateFloatAsState(
        targetValue = if (isDragging) 1.15f else if (isExpanded) 0.9f else 1.0f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy)
    )

    // Function to calculate selection
    fun updateActiveAction(localDragPos: Offset) {
        val distancePx = with(density) { 75.dp.toPx() }
        val thresholdPx = with(density) { 40.dp.toPx() } // Hit zone radius
        
        // Calculate bubble centers relative to the FAB's center
        // Sprout angle calculations
        val angleDeg = 45.0
        
        fun rotateOffset(offset: Offset, deg: Double): Offset {
            val rad = Math.toRadians(deg)
            val sinTheta = sin(rad).toFloat()
            val cosTheta = cos(rad).toFloat()
            return Offset(
                x = offset.x * cosTheta - offset.y * sinTheta,
                y = offset.x * sinTheta + offset.y * cosTheta
            )
        }

        val undoDir = rotateOffset(sproutDirection, -angleDeg)
        val redoDir = rotateOffset(sproutDirection, angleDeg)
        
        val summonPos = sproutDirection * distancePx
        val undoPos = undoDir * distancePx
        val redoPos = redoDir * distancePx

        val dUndo = (localDragPos - undoPos).getDistance()
        val dSummon = (localDragPos - summonPos).getDistance()
        val dRedo = (localDragPos - redoPos).getDistance()

        val previousAction = activeAction

        activeAction = when {
            dUndo < thresholdPx && canUndo -> CommandAction.Undo
            dSummon < thresholdPx -> CommandAction.Summon
            dRedo < thresholdPx && canRedo -> CommandAction.Redo
            else -> null
        }

        if (activeAction != previousAction && activeAction != null) {
            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove) // Light haptic
        }
    }

    fun snapToNearest() {
        val minX = paddingPx + buttonSizePx / 2
        val maxX = parentSize.width - paddingPx - buttonSizePx / 2
        val minY = paddingPx + 60.dp.value * density.density + buttonSizePx / 2 // Safe top area
        val maxY = parentSize.height - paddingPx - buttonSizePx / 2
        
        val centerX = parentSize.width / 2f
        val centerY = parentSize.height / 2f

        val points = listOf(
            Offset(minX, minY), Offset(centerX, minY), Offset(maxX, minY),
            Offset(minX, centerY), Offset(maxX, centerY),
            Offset(minX, maxY), Offset(centerX, maxY), Offset(maxX, maxY)
        )

        val target = points.minByOrNull { (it - position.value).getDistance() } ?: points.last()
        coroutineScope.launch {
            position.animateTo(
                targetValue = target,
                animationSpec = spring(dampingRatio = 0.7f, stiffness = Spring.StiffnessMediumLow)
            )
            haptic.performHapticFeedback(HapticFeedbackType.LongPress) // "Rigid" haptic equivalent
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .onSizeChanged { parentSize = it }
    ) {
        if (isExpanded) {
            // Dismissal layer
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.01f)) // Invisible but catches taps
                    .pointerInput(Unit) {
                        awaitEachGesture {
                            awaitFirstDown()
                            isExpanded = false
                        }
                    }
            )
        }

        // Layer 0: Quick Action Bubbles
        if (position.value != Offset.Zero) {
            QuickActionBubbles(
                center = position.value,
                sproutDirection = sproutDirection,
                isExpanded = isExpanded,
                activeAction = activeAction,
                canUndo = canUndo,
                canRedo = canRedo,
                onUndo = onUndo,
                onSummon = onSummonCoCaptain,
                onRedo = onRedo
            )
        }

        // Layer 1: Main Button
        if (position.value != Offset.Zero) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .offset {
                        IntOffset(
                            x = (position.value.x - buttonSizePx / 2).roundToInt(),
                            y = (position.value.y - buttonSizePx / 2).roundToInt()
                        )
                    }
                    .size(64.dp)
                    .scale(buttonScale)
                    .shadow(
                        elevation = if (isDragging || isExpanded) 15.dp else 10.dp,
                        shape = CircleShape,
                        spotColor = if (isDragging || isExpanded) Color.Black.copy(alpha = 0.35f) else Color.Black.copy(alpha = 0.2f)
                    )
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.8f))
                    .border(0.5.dp, Color.White.copy(alpha = 0.2f), CircleShape)
                    .pointerInput(Unit) {
                        coroutineScope {
                            awaitEachGesture {
                                val down = awaitFirstDown(requireUnconsumed = false)
                                var isLongPress = false
                                var isDraggingLocal = false
                                var activeJob: Job? = launch {
                                    delay(250)
                                    if (!isDraggingLocal) {
                                        isLongPress = true
                                        isExpanded = true
                                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                    }
                                }

                                var localDragPos = Offset.Zero

                                do {
                                    val event = awaitPointerEvent()
                                    val change = event.changes.firstOrNull() ?: break
                                    
                                    val distance = (change.position - down.position).getDistance()
                                    localDragPos = change.position - Offset(buttonSizePx/2, buttonSizePx/2)

                                    if (isExpanded) {
                                        updateActiveAction(localDragPos)
                                        if (change.positionChange() != Offset.Zero) change.consume()
                                    } else {
                                        if (!isLongPress && distance > 10.dp.toPx()) {
                                            activeJob?.cancel()
                                            isDraggingLocal = true
                                            isDragging = true
                                        }

                                        if (isDraggingLocal) {
                                            val delta = change.positionChange()
                                            launch {
                                                position.snapTo(position.value + delta)
                                            }
                                            change.consume()
                                        }
                                    }
                                } while (event.changes.any { it.pressed })

                                activeJob?.cancel()

                                if (isExpanded) {
                                    val actionToExecute = activeAction
                                    activeAction = null
                                    isExpanded = false
                                    if (actionToExecute != null) {
                                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                        when (actionToExecute) {
                                            CommandAction.Undo -> onUndo()
                                            CommandAction.Summon -> onSummonCoCaptain()
                                            CommandAction.Redo -> onRedo()
                                        }
                                    }
                                } else if (isDraggingLocal) {
                                    isDragging = false
                                    snapToNearest()
                                } else {
                                    // Tap
                                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                    onTap()
                                }
                            }
                        }
                    }
            ) {
                Icon(
                    imageVector = if (isExpanded) Icons.Default.Close else Icons.Default.Build, // Placeholder for Command
                    contentDescription = "Command Palette",
                    tint = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier
                        .size(24.dp)
                        .graphicsLayer {
                            rotationZ = if (isExpanded) 90f else 0f
                        }
                )
            }
        }
    }
}

@Composable
fun BoxScope.QuickActionBubbles(
    center: Offset,
    sproutDirection: Offset,
    isExpanded: Boolean,
    activeAction: CommandAction?,
    canUndo: Boolean,
    canRedo: Boolean,
    onUndo: () -> Unit,
    onSummon: () -> Unit,
    onRedo: () -> Unit
) {
    val density = LocalDensity.current
    val distancePx = with(density) { 75.dp.toPx() }
    
    val angleDeg = 45.0
    fun rotateOffset(offset: Offset, deg: Double): Offset {
        val rad = Math.toRadians(deg)
        val sinTheta = sin(rad).toFloat()
        val cosTheta = cos(rad).toFloat()
        return Offset(
            x = offset.x * cosTheta - offset.y * sinTheta,
            y = offset.x * sinTheta + offset.y * cosTheta
        )
    }

    val undoDir = rotateOffset(sproutDirection, -angleDeg)
    val redoDir = rotateOffset(sproutDirection, angleDeg)

    // Center: Summon
    QuickActionBubble(
        center = center,
        offsetDirection = sproutDirection,
        distancePx = distancePx,
        icon = Icons.Default.Star, // Placeholder for Sparkles
        color = Color(0xFF0066FF),
        isExpanded = isExpanded,
        isHighlighted = activeAction == CommandAction.Summon,
        isEnabled = true,
        sizeDp = 48.dp,
        onAction = onSummon
    )

    // Left: Undo
    QuickActionBubble(
        center = center,
        offsetDirection = undoDir,
        distancePx = distancePx,
        icon = Icons.Default.Refresh, // Placeholder for Undo
        color = Color.Gray,
        isExpanded = isExpanded,
        isHighlighted = activeAction == CommandAction.Undo,
        isEnabled = canUndo,
        sizeDp = 40.dp,
        onAction = onUndo
    )

    // Right: Redo
    QuickActionBubble(
        center = center,
        offsetDirection = redoDir,
        distancePx = distancePx,
        icon = Icons.Default.Refresh, // Placeholder for Redo
        color = Color.Gray,
        isExpanded = isExpanded,
        isHighlighted = activeAction == CommandAction.Redo,
        isEnabled = canRedo,
        sizeDp = 40.dp,
        onAction = onRedo
    )
}

@Composable
fun QuickActionBubble(
    center: Offset,
    offsetDirection: Offset,
    distancePx: Float,
    icon: ImageVector,
    color: Color,
    isExpanded: Boolean,
    isHighlighted: Boolean,
    isEnabled: Boolean,
    sizeDp: androidx.compose.ui.unit.Dp,
    onAction: () -> Unit
) {
    val density = LocalDensity.current
    val sizePx = with(density) { sizeDp.toPx() }
    
    val finalPos = center + (offsetDirection * distancePx)
    
    val currentPos = if (isExpanded) finalPos else center
    val scale by animateFloatAsState(
        targetValue = if (isExpanded) { if (isHighlighted) 1.25f else 1.0f } else 0.01f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy)
    )

    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .offset {
                IntOffset(
                    x = (currentPos.x - sizePx / 2).roundToInt(),
                    y = (currentPos.y - sizePx / 2).roundToInt()
                )
            }
            .size(sizeDp)
            .scale(scale)
            .shadow(
                elevation = if (isHighlighted) 12.dp else if (isEnabled) 8.dp else 0.dp,
                shape = CircleShape,
                spotColor = color.copy(alpha = if (isHighlighted) 0.5f else if (isEnabled) 0.2f else 0f)
            )
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.8f))
            .border(
                width = if (isHighlighted) 2.dp else 1.dp,
                color = if (isHighlighted) color else color.copy(alpha = if (isEnabled) 0.3f else 0.1f),
                shape = CircleShape
            )
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = color.copy(alpha = if (isEnabled) 1.0f else 0.3f),
            modifier = Modifier.size(sizeDp * 0.4f)
        )
    }
}
