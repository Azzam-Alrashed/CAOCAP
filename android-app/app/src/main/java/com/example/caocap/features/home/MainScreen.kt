package com.example.caocap.features.home

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.navigation3.runtime.NavKey
import com.example.caocap.features.canvas.InfiniteCanvas
import com.example.caocap.features.overlays.FloatingCommandButton

import com.example.caocap.theme.CAOCAPTheme

@Composable
fun MainScreen(
  onItemClick: (NavKey) -> Unit,
  modifier: Modifier = Modifier
) {
  Box(modifier = modifier.fillMaxSize()) {
    InfiniteCanvas()
    FloatingCommandButton(
      onTap = { /* TODO: Open Command Palette */ },
      onUndo = { /* TODO: Undo */ },
      onRedo = { /* TODO: Redo */ },
      onSummonCoCaptain = { /* TODO: Summon */ },
      canUndo = false,
      canRedo = false
    )
  }
}

@Preview(showBackground = true)
@Composable
fun MainScreenPreview() {
  CAOCAPTheme { 
    MainScreen(onItemClick = {}) 
  }
}
