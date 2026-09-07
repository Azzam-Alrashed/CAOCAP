# Canvas Feature

The existing Canvas feature is the temporary surface inside each agent's Workspace. It renders ordinary cards, sub-canvases, links, pan, zoom, save, and undo.

Home is an agent library. Opening an agent selects its own saved canvas, initially empty. The mind map and flowchart design and behavior remain TBD.

## Ownership

- `ProjectStore` owns durable canvas state: nodes, viewport offset, viewport scale, and persistence.
- `InfiniteCanvasView` owns transient interaction state: active viewport gestures, selected node, node drag offsets, and whether a node is currently being dragged.
- `ViewportState` owns pan and zoom math. Keep gesture calculations here instead of spreading geometry math through views.
- `NodeView` renders one node. It should stay presentational.
- `NodeDetailView` inspects a node as a card. It does not open an HTML editor or publish sheet.
- Providers under `Providers/` define the empty root canvas. They do not seed demo apps.

## Data Flow

1. `ContentView` provides an active `ProjectStore` from `AppRouter`.
2. `InfiniteCanvasView` renders `store.nodes`.
3. Tapping a card inspects it. Tapping an action node calls `onNodeAction`. Tapping a subcanvas portal opens its linked canvas file.
4. `ProjectStore` debounces saves. New cards persist title and position. Saves do not write HTML or SRS.
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
- Keep `NodeDetailView` focused on card inspection; put persistent mutations in store methods.
- If adding a node type, update `SpatialNode`, `NodeDetailView`, and `ProjectContextBuilder`.
- Do not add HTML, SRS, or live-preview compilation back onto cards.

## Verification Checklist

- Fresh install: Home shows CoCaptain and CoStar. Open either to reach its empty Workspace, with pan, zoom, and the agent FAB.
- Create a card, drag it, pan, pinch zoom, quit, and reopen. Position and title remain.
- Check connection arrows while dragging nodes and at multiple zoom levels.
- FAB tap or ⌘J opens CoCaptain chat (or closes listed sheets if one is already open). Long-press the FAB for Chat / Voice / Video.

## Test Targets

Useful test coverage for this feature:

- `ViewportState` pan and zoom math.
- save/load of node positions, links, and viewport state.
- leftover files with `type: "miniApp"` decode as ordinary cards.
- tapping a leftover card inspects it instead of opening an editor.
