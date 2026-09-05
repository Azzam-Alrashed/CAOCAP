# CAOCAP Product Vision

## Purpose

CAOCAP is a platform where people discover, build, and publish AI agents together.

Its purpose is to help people turn ideas into useful agents through shared work. Users can explore what others have built, create their own agents, and collaborate to test, improve, and publish them.

The experience centers on three activities: **Explore, Build, and Collaborate.**

## Target audience

CAOCAP is for people who want to discover useful AI agents or contribute to building them.

- **Explorers** want to find and try agents that address their needs.
- **Builders** want to turn ideas into working agents and publish them.
- **Collaborators** want to contribute knowledge, tools, testing, or feedback to shared projects.

These roles can overlap. The experience should welcome newcomers while supporting experienced builders and teams.

## Problem

People exploring AI agents need to understand what an agent does, whether it fits their needs, and how well it works before using it.

Builders need to turn ideas into working agents, test their behavior, and make them available to others. When people build together, they also need a way to coordinate contributions, review changes, and maintain a shared project.

CAOCAP aims to connect these activities so people can discover existing work, contribute improvements, and publish useful agents together.

## Product approach

CAOCAP is intended to bring discovery, agent creation, and shared project work into one platform. The following capabilities describe the planned experience.

### Explore

Users should be able to discover agents, understand their purpose and limitations, and try them on relevant tasks. Exploration should also help people find projects where they can contribute.

### Build

Builders should be able to define an agent's purpose, shape its instructions, connect the tools and knowledge it needs, and test its behavior. They should be able to improve their work before publishing an agent for others to use.

To build agents, users will use mindmaps to organize context and the agent's knowledge base, and flowcharts to define logic, operations, and conditional flows.

### Collaborate

People should be able to work on shared projects and contribute instructions, tools, knowledge, mindmap and flowchart changes, tests, or feedback. The experience should make contributions and proposed changes understandable so collaborators can review, test, and improve an agent together.

Publishing connects the three activities: agents become available for others to explore and use, and feedback can guide further improvements.

## Intended user journey

1. **Explore:** Discover agents, try them, and identify a useful starting point or an unmet need.
2. **Start or join:** Create a project with a clear purpose or join an existing project.
3. **Build:** Organize the agent's context and knowledge in mindmaps, define its logic and conditional flows in flowcharts, and connect the tools needed for its task.
4. **Collaborate and test:** Contribute work, review changes, and test the agent against example tasks.
5. **Publish:** Make a tested version available with a clear description of what it does and its limitations.
6. **Improve together:** Use feedback and observed results to refine the agent and publish updates.

People can enter at different points. Some may only explore and use agents; others may build independently or contribute to shared projects.

## Product principles

### Useful outcomes

Agents should have a clear purpose. Their usefulness should be demonstrated through results on relevant tasks.

### Collaboration is part of building

Contributing, reviewing changes, and testing together should be part of the project workflow. People should understand how their contributions affect the shared agent.

### Test before publishing

Builders should evaluate an agent's behavior before making it available to others. Test results and known limitations should guide improvements and help users decide whether the agent fits their needs.

### Clear and approachable

Language, navigation, and feedback should welcome newcomers while giving experienced builders enough detail to understand and improve their work.

### Fun to build with

Building an agent should feel like playing with ideas and watching them come alive. On iOS and macOS, the intended canvas experience will combine rounded nodes, soft connections, readable labels, and purposeful color to distinguish knowledge, actions, and conditions.

Nodes should snap into place, and connections should respond as users draw them. During tests, the flowchart should light up along the path the agent actually takes. A small, brief celebration should acknowledge a first successful run without implying that its answer is correct. Labels and symbols should support color cues, and reduced-motion alternatives should preserve essential feedback.

### Ownership and attribution

People should retain control over their projects and understand who can contribute, change, or publish shared work. Contributions should be credited clearly.

### Trust through transparency

Users should understand what an agent does, what tools and information it uses, and where its limitations lie. Descriptions and examples should accurately represent its behavior.

## Development order

Development will start with iOS and macOS, followed by the other platforms.

## Related documentation

- [Repository README](../README.md)
- [Software Requirements Specification](SRS.md)
