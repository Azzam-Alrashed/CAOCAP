import subprocess
import os

parent_issue = "#8"

issues = [
    {
        "title": "Extract ProjectPersistenceEngine",
        "body": f"""## Parent

{parent_issue}

## What to build

Extract the persistence logic (save, load, debouncing) from `ProjectStore` into a dedicated `ProjectPersistenceEngine`. Create comprehensive unit tests for the extracted engine. Keep `ProjectStore`'s public API unchanged.

## Acceptance criteria

- [ ] `ProjectPersistenceEngine` is created in `Services/ProjectStore/`
- [ ] Persistence logic is successfully migrated from `ProjectStore` to `ProjectPersistenceEngine`
- [ ] Unit tests for `ProjectPersistenceEngine` are added and pass
- [ ] App compiles and runs with no regressions in persistence behavior

## Blocked by

None - can start immediately
"""
    },
    {
        "title": "Extract CheckpointEngine",
        "body": """## Parent

{parent_issue}

## What to build

Extract the checkpoint creation and restoration logic from `ProjectStore` into a dedicated `CheckpointEngine`. Preserve the existing UndoManager behavior exactly. Create comprehensive unit tests for the extracted engine.

## Acceptance criteria

- [ ] `CheckpointEngine` is created in `Services/ProjectStore/`
- [ ] Checkpoint logic is successfully migrated
- [ ] Undo/Redo behavior works exactly as before
- [ ] Unit tests for `CheckpointEngine` are added and pass

## Blocked by

- #{prev_issue}
"""
    },
    {
        "title": "Extract LivePreviewEngine",
        "body": """## Parent

{parent_issue}

## What to build

Extract the live preview compilation logic from `ProjectStore` into a dedicated `LivePreviewEngine`. Create unit tests for the extracted engine.

## Acceptance criteria

- [ ] `LivePreviewEngine` is created in `Services/ProjectStore/`
- [ ] Compilation logic is successfully migrated
- [ ] Live preview updates in the app continue to function correctly
- [ ] Unit tests for `LivePreviewEngine` are added and pass

## Blocked by

- #{prev_issue}
"""
    },
    {
        "title": "Extract ReactiveGraphEngine",
        "body": """## Parent

{parent_issue}

## What to build

Extract the reactive graph calculation and node linking logic from `ProjectStore` into a dedicated `ReactiveGraphEngine`. Create unit tests for the extracted engine.

## Acceptance criteria

- [ ] `ReactiveGraphEngine` is created in `Services/ProjectStore/`
- [ ] Reactive graph logic is successfully migrated
- [ ] Node connections and evaluations function correctly
- [ ] Unit tests for `ReactiveGraphEngine` are added and pass

## Blocked by

- #{prev_issue}
"""
    },
    {
        "title": "Extract NodeMutationEngine",
        "body": """## Parent

{parent_issue}

## What to build

Extract the node mutation logic (adding, removing, updating positions) from `ProjectStore` into a dedicated `NodeMutationEngine`. Create unit tests for the extracted engine.

## Acceptance criteria

- [ ] `NodeMutationEngine` is created in `Services/ProjectStore/`
- [ ] Node mutation logic is successfully migrated
- [ ] Adding, removing, and moving nodes functions correctly on the canvas
- [ ] Unit tests for `NodeMutationEngine` are added and pass

## Blocked by

- #{prev_issue}
"""
    },
    {
        "title": "Extract AgentPipelineEngine",
        "body": """## Parent

{parent_issue}

## What to build

Extract the agent pipeline state and flow logic from `ProjectStore` into a dedicated `AgentPipelineEngine`. Create unit tests for the extracted engine.

## Acceptance criteria

- [ ] `AgentPipelineEngine` is created in `Services/ProjectStore/`
- [ ] Agent flow logic is successfully migrated
- [ ] CoCaptain agent interactions function correctly
- [ ] Unit tests for `AgentPipelineEngine` are added and pass

## Blocked by

- #{prev_issue}
"""
    }
]

prev_issue_num = ""

for i, issue in enumerate(issues):
    body = issue["body"].replace("{parent_issue}", parent_issue)
    if "{prev_issue}" in body:
        body = body.replace("{prev_issue}", prev_issue_num)
    
    with open("temp_issue_body.md", "w") as f:
        f.write(body)
        
    cmd = ["gh", "issue", "create", "--title", issue["title"], "--body-file", "temp_issue_body.md"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Failed to create issue: {result.stderr}")
        exit(1)
        
    url = result.stdout.strip()
    issue_num = url.split("/")[-1]
    prev_issue_num = issue_num
    print(f"Created issue {issue_num}: {url}")

os.remove("temp_issue_body.md")
