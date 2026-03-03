# LangGraph Skill for Claude Code

A comprehensive [Claude Code](https://code.claude.com) skill that makes Claude an expert at building [LangGraph](https://www.langchain.com/langgraph) agentic AI workflows.

## What This Skill Does

When installed, Claude Code gains deep knowledge of LangGraph and can:

- **Design** graph architectures using an architecture decision tree
- **Build** StateGraph workflows with nodes, edges, state management, and reducers
- **Create** ReAct agents, routers, multi-agent supervisors, and custom workflows
- **Implement** human-in-the-loop patterns with `interrupt()` and `Command(resume=...)`
- **Add** persistence with checkpointers (MemorySaver, PostgresSaver, SQLite, MongoDB)
- **Configure** long-term memory with Store and namespaces
- **Set up** streaming (values, updates, messages, custom events)
- **Deploy** to LangGraph Platform (Cloud or Self-hosted)
- **Write** production-ready code with correct imports, patterns, and best practices

## Installation

### Option 1: Clone and Install (Recommended)

```bash
git clone https://github.com/YOUR_USERNAME/Claude-Code-LangGraph-Skill.git
cd Claude-Code-LangGraph-Skill
./install.sh
```

### Option 2: Make Install

```bash
git clone https://github.com/YOUR_USERNAME/Claude-Code-LangGraph-Skill.git
cd Claude-Code-LangGraph-Skill
make install
```

### Option 3: Manual

Copy the `src/` contents to `~/.claude/skills/langgraph/`:

```bash
mkdir -p ~/.claude/skills/langgraph/references ~/.claude/skills/langgraph/examples
cp src/SKILL.md ~/.claude/skills/langgraph/SKILL.md
cp src/references/*.md ~/.claude/skills/langgraph/references/
cp src/examples/*.md ~/.claude/skills/langgraph/examples/
```

### Option 4: Download Release

1. Go to [Releases](../../releases)
2. Download the `.zip` file
3. Extract to `~/.claude/skills/langgraph/`

## Usage

The skill activates automatically when you ask Claude Code about LangGraph. You can also invoke it directly:

```
/langgraph build a ReAct agent with web search
/langgraph create a multi-agent supervisor system
/langgraph add human-in-the-loop to my workflow
/langgraph help me deploy my agent
```

Or just ask naturally:

```
"Create a LangGraph workflow that processes customer support tickets"
"How do I add memory to my LangGraph agent?"
"Build a parallel research agent with map-reduce"
```

## What's Included

```
src/
├── SKILL.md                         # Core skill (architecture guide, quick reference, patterns)
├── references/
│   ├── api-reference.md             # Complete import map, StateGraph API, all signatures
│   └── patterns.md                  # 13 advanced patterns with full code
└── examples/
    └── complete-examples.md         # 6 production-ready working examples
```

### Patterns Covered

| Pattern | Description |
|---------|-------------|
| ReAct Agent | Tool-calling agent with reasoning loop |
| Router | Conditional branching to specialized handlers |
| Human-in-the-Loop | `interrupt()` + `Command(resume=...)` approval flows |
| Map-Reduce | Parallel processing with `Send()` API |
| Sub-Graphs | Nested modular graphs |
| Supervisor | Multi-agent orchestration with routing LLM |
| Memory Agent | Persistent user profiles with Trustcall |
| Chatbot Summarization | Conversation compression for token management |
| Streaming | Values, updates, messages, custom events |
| Time Travel | State history, replay, and state editing |
| Double Texting | Handling concurrent user messages |
| Functional API | `@entrypoint` + `@task` — durable workflows without graphs |
| Error Handling | `RetryPolicy` with exponential backoff |

### API Coverage

- `StateGraph`, `MessagesState`, `START`, `END`
- `Send`, `Command`, `interrupt`
- `ToolNode`, `tools_condition`, `create_react_agent`
- `MemorySaver`, `PostgresSaver`, `SqliteSaver`, `MongoDBSaver`
- `InMemoryStore`, `BaseStore`
- Streaming modes: `values`, `updates`, `messages`, `custom`, `debug`
- Configuration schemas, deployment config, LangGraph SDK client

## Uninstall

```bash
./install.sh --uninstall
# or
make uninstall
# or
rm -rf ~/.claude/skills/langgraph
```

## Building Distribution Packages

```bash
make package           # Creates dist/langgraph-v1.0.0.zip
make package-combined  # Creates dist/langgraph-v1.0.0-combined.md (single file)
make all               # Both
```

## Creating a Release

1. Update `VERSION` file
2. Update `CHANGELOG.md`
3. Commit and tag:
   ```bash
   git add -A
   git commit -m "Release v1.0.0"
   git tag v1.0.0
   git push origin main --tags
   ```
4. GitHub Actions automatically builds and publishes the release with artifacts

## Changelog

### v0.3.0 — Functional API + Error Handling (2026-03-03)
- Added Pattern 12: Functional API (`@entrypoint` + `@task`) for durable workflows without explicit graphs
- Added Pattern 13: Error Handling with `RetryPolicy` — automatic retries with exponential backoff
- Added Functional API and RetryPolicy sections to api-reference.md
- Updated SKILL.md decision guide, quick reference, and implementation guidelines

### v0.2.0 — Bug Fixes (2026-03-03)
- Fixed all 10 code bugs across patterns and examples — every code block is now copy-paste runnable
- Added missing imports, model definitions, and variable initializations to Patterns 2-8
- Fixed critical `**Command(goto=...)` unpacking bug in Example 3 (replaced with `Command(goto=..., update={...})`)

### v0.1.0 — Initial Release (2026-03-03)
- Core SKILL.md, API reference, 11 patterns, 6 examples

See [CHANGELOG.md](CHANGELOG.md) for full details.

## License

MIT License - see [LICENSE](LICENSE)

## Acknowledgments

- [LangGraph](https://github.com/langchain-ai/langgraph) by LangChain
- [LangChain Academy](https://github.com/langchain-ai/langchain-academy) for the training material
- [Agent Skills Standard](https://agentskills.io) for the open skill format
- Inspired by [iterative-planner](https://github.com/NikolasMarkou/iterative-planner) skill structure
