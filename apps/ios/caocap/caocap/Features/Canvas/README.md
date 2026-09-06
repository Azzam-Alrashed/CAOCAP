# Canvas Feature

The Canvas feature is CAOCAP's spatial runtime. It renders the infinite workspace, Mini-App nodes, sub-canvases, links, embedded previews, and editor overlays.

## Ownership

- `ProjectStore` owns durable canvas state: nodes, viewport offset, viewport scale, and persistence.
- `InfiniteCanvasView` owns transient interaction state: active viewport gestures, selected node, node drag offsets, and whether a node is currently being dragged.
- `ViewportState` owns pan and zoom math. Keep gesture calculations here instead of spreading geometry math through views.
- `NodeView` renders one node. It should stay presentational.
- `NodeDetailView` inspects a node as a card. It does not open a live HTML preview or publish sheet.
- Providers under `Providers/` define the root constellation, curated Tutorial
  and Pac-Man canvases, and generic Mini-App starter content.
- The protected Activity action node renders the device-wide 17-week save
  heatmap directly on the root canvas and opens the expanded activity sheet.

## Data Flow

1. `ContentView` provides an active `ProjectStore` from `AppRouter`.
2. `InfiniteCanvasView` renders `store.nodes`.
3. Tapping a leftover Mini-App inspects the card, tapping an action node calls
   `onNodeAction`, and tapping a subcanvas portal opens its linked canvas file.
4. `ProjectStore` debounces saves. It does not compile live HTML previews.
5. `ConnectionLayer` draws arrows from `nextNodeId` and `connectedNodeIds`.

Views should call store methods rather than mutating `store.nodes` directly.

## Coordinate Model

- `SpatialNode.position` is a canvas-space offset from the visible center.
- `ViewportState.offset` and `ViewportState.scale` transform the whole node layer.
- `ConnectionLayer` manually converts node positions into screen-space coordinates so links do not clip during pan and zoom.
- The canvas forces left-to-right layout where spatial math depends on predictable coordinates.

When changing gestures or connection rendering, test pan, zoom, drag, and arrow placement together.



## Editing Guidance

- Put reusable node graph construction in `Providers/`, not in `AppRouter` or large views.
- Keep `NodeView` focused on visual rendering. Put editing behavior in sheet views or store methods.
- Keep `NodeDetailView` focused on Mini-App preview/tool routing; put persistent mutations in store methods.
- If adding a node type, update `SpatialNode`, `NodeDetailView`, `ProjectContextBuilder`, and any CoCaptain role/patch behavior that should understand it.
- Mini-App preview content should flow through `ProjectStore` compilation instead of being assembled in UI components.

## Verification Checklist

- Create/open a project and confirm nodes render at the expected zoom.
- Drag a node, pan the canvas, pinch zoom, then reopen the project and verify persisted state.
- Edit a Mini-App's Code tool and confirm the Mini-App preview updates.
- Open a Mini-App node full-screen and confirm FAB tap and sparkles open the omnibox; verify MINI-APP rows route to SRS, Code, Firebase, Agent, Settings, Publish, and Back to Canvas.
- Pro users: publish a Mini-App, confirm live GitHub Pages URL, and verify Safari Add to Home Screen steps appear.
- Check connection arrows while dragging nodes and at multiple zoom levels.
- Verify action nodes on the Home screen navigate to correct destinations.
- Make a saved change on any canvas, return to Root, and confirm the Activity
  node and expanded sheet update without counting failed or cancelled saves.

## Test Targets

Useful test coverage for this feature:

- `ViewportState` pan and zoom math.
- `ProjectStore` Mini-App preview compilation.
- save/load of node positions, links, and viewport state.
- provider output for required home action nodes.
