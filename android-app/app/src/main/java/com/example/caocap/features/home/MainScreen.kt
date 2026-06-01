package com.example.caocap.features.home

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.navigation3.runtime.NavKey
import com.example.caocap.features.canvas.InfiniteCanvas

import com.example.caocap.theme.CAOCAPTheme

@Composable
fun MainScreen(
  onItemClick: (NavKey) -> Unit,
  modifier: Modifier = Modifier
) {
  InfiniteCanvas(modifier = modifier)
}

@Preview(showBackground = true)
@Composable
fun MainScreenPreview() {
  CAOCAPTheme { 
    MainScreen(onItemClick = {}) 
  }
}
