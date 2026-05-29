#!/bin/bash
set -e

PARENT_ISSUE="#8"

# Issue 1
ISSUE1_URL=$(gh issue create --title "Extract ProjectPersistenceEngine" -F - << BODYEOF
## Parent

$PARENT_ISSUE

## What to build

Extract the persistence logic (save, load, debouncing) from \`ProjectStore\` into a dedicated \`ProjectPersistenceEngine\`. Create comprehensive unit tests for the extracted engine. Keep \`ProjectStore\`'s public API unchanged.

## Acceptance criteria

- [ ] \`ProjectPersistenceEngine\` is created in \`Services/ProjectStore/\`
- [ ] Persistence logic is successfully migrated from \`ProjectStore\` to \`ProjectPersistenceEngine\`
- [ ] Unit tests for \`ProjectPersistenceEngine\` are added and pass
- [ ] App compiles and runs with no regressions in persistence behavior

## Blocked by

None - can start immediately
BODYEOF
)
ISSUE1_NUM=$(basename "$ISSUE1_URL")
echo "Created $ISSUE1_URL"

# Issue 2
ISSUE2_URL=$(gh issue create --title "Extract CheckpointEngine" -F - << BODYEOF
## Parent

$PARENT_ISSUE

## What to build

Extract the checkpoint creation and restoration logic from \`ProjectStore\` into a dedicated \`CheckpointEngine\`. Preserve the existing UndoManager behavior exactly. Create comprehensive unit tests for the extracted engine.

## Acceptance criteria

- [ ] \`CheckpointEngine\` is created in \`Services/ProjectStore/\`
- [ ] Checkpoint logic is successfully migrated
- [ ] Undo/Redo behavior works exactly as before
- [ ] Unit tests for \`CheckpointEngine\` are added and pass

## Blocked by

- #$ISSUE1_NUM
BODYEOF
)
ISSUE2_NUM=$(basename "$ISSUE2_URL")
echo "Created $ISSUE2_URL"

# Issue 3
ISSUE3_URL=$(gh issue create --title "Extract LivePreviewEngine" -F - << BODYEOF
## Parent

$PARENT_ISSUE

## What to build

Extract the live preview compilation logic from \`ProjectStore\` into a dedicated \`LivePreviewEngine\`. Create unit tests for the extracted engine.

## Acceptance criteria

- [ ] \`LivePreviewEngine\` is created in \`Services/ProjectStore/\`
- [ ] Compilation logic is successfully migrated
- [ ] Live preview updates in the app continue to function correctly
- [ ] Unit tests for \`LivePreviewEngine\` are added and pass

## Blocked by

- #$ISSUE2_NUM
BODYEOF
)
ISSUE3_NUM=$(basename "$ISSUE3_URL")
echo "Created $ISSUE3_URL"

# Issue 4
ISSUE4_URL=$(gh issue create --title "Extract ReactiveGraphEngine" -F - << BODYEOF
## Parent

$PARENT_ISSUE

## What to build

Extract the reactive graph calculation and node linking logic from \`ProjectStore\` into a dedicated \`ReactiveGraphEngine\`. Create unit tests for the extracted engine.

## Acceptance criteria

- [ ] \`ReactiveGraphEngine\` is created in \`Services/ProjectStore/\`
- [ ] Reactive graph logic is successfully migrated
- [ ] Node connections and evaluations function correctly
- [ ] Unit tests for \`ReactiveGraphEngine\` are added and pass

## Blocked by

- #$ISSUE3_NUM
BODYEOF
)
ISSUE4_NUM=$(basename "$ISSUE4_URL")
echo "Created $ISSUE4_URL"

# Issue 5
ISSUE5_URL=$(gh issue create --title "Extract NodeMutationEngine" -F - << BODYEOF
## Parent

$PARENT_ISSUE

## What to build

Extract the node mutation logic (adding, removing, updating positions) from \`ProjectStore\` into a dedicated \`NodeMutationEngine\`. Create unit tests for the extracted engine.

## Acceptance criteria

- [ ] \`NodeMutationEngine\` is created in \`Services/ProjectStore/\`
- [ ] Node mutation logic is successfully migrated
- [ ] Adding, removing, and moving nodes functions correctly on the canvas
- [ ] Unit tests for \`NodeMutationEngine\` are added and pass

## Blocked by

- #$ISSUE4_NUM
BODYEOF
)
ISSUE5_NUM=$(basename "$ISSUE5_URL")
echo "Created $ISSUE5_URL"

# Issue 6
ISSUE6_URL=$(gh issue create --title "Extract AgentPipelineEngine" -F - << BODYEOF
## Parent

$PARENT_ISSUE

## What to build

Extract the agent pipeline state and flow logic from \`ProjectStore\` into a dedicated \`AgentPipelineEngine\`. Create unit tests for the extracted engine.

## Acceptance criteria

- [ ] \`AgentPipelineEngine\` is created in \`Services/ProjectStore/\`
- [ ] Agent flow logic is successfully migrated
- [ ] CoCaptain agent interactions function correctly
- [ ] Unit tests for \`AgentPipelineEngine\` are added and pass

## Blocked by

- #$ISSUE5_NUM
BODYEOF
)
echo "Created $ISSUE6_URL"
