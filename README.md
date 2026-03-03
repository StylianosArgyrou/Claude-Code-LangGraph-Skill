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
mkdir -p ~/.claude/skills/langgraph/examples
cp src/SKILL.md src/api-reference.md src/patterns.md ~/.claude/skills/langgraph/
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

### Example: Cooking Assistant (from vague idea to full app)

A single prompt like this:

```
/langgraph Build a cooking assistant with 2 specialized agents:
1. "recipe_finder" — searches recipe database based on available ingredients,
   filters by user dietary preferences from memory store
2. "cooking_guide" — walks user through recipe step-by-step with a timer tool

Architecture: Supervisor StateGraph routes between agents based on conversation phase.
Use create_react_agent for recipe_finder with search tool and RetryPolicy.
Add MemorySaver for session persistence.
Add InMemoryStore for user profiles with namespace ("cooking", user_id) storing
dietary preferences and favorite recipes.
Stream with stream_mode="messages" for real-time cooking step narration.
Save to cooking_assistant.py.
```

...generates a complete, runnable multi-agent app. Claude will tell you which API keys to add to a `.env` file.

## What's Included

```
src/
├── SKILL.md                     # Core skill (architecture guide, quick reference, patterns)
├── api-reference.md             # Complete import map, StateGraph API, all signatures
├── patterns.md                  # 16 advanced patterns with full code
└── examples/
    └── complete-examples.md     # 10 production-ready working examples
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
| Async Execution | `async def` nodes + `ainvoke` / `astream` |
| Adaptive RAG | Conditional routing + retrieval + generation |
| Self-Correcting Code | Reflexion loop with validation |
| Support with Escalation | Routing + HITL escalation |
| Testing Graphs | pytest with mocked LLMs and routing tests |
| Production Migration | MemorySaver → PostgresSaver/RedisSaver |

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

### v1.7.0 — Interactive Prompt Wizard (2026-03-03)
- Added Prompt Builder Protocol: 8 guided questions that transform vague ideas into optimized /langgraph prompts
- 4 prompt templates (simple agent, multi-agent, RAG, workflow automation) + construction formula
- Example 12: Full Prompt Wizard walkthrough from vague idea to generated app

### v1.6.1 — Pattern Showcase Demo (2026-03-03)
- Added Example 11: Multi-Agent Research System exercising 11 patterns in one app
- Demo prompt validated: fresh subagent generates and runs full system from `/langgraph` prompt

### v1.6.0 — Interrupt Safety + Graph vs Functional API (2026-03-03)
- Added Pattern 24: Interrupt Safety Rules (idempotency, side effect placement, JSON payloads)
- Added Pattern 25: Graph API vs Functional API Decision Guide with comparison table
- Interrupt safety notes in api-reference.md, anti-pattern #9
- Guidelines #24-25 for interrupt safety and API selection

### v1.5.0 — create_agent + Middleware + Recursion Limits (2026-03-03)
- Added Pattern 22: `create_agent` with Middleware (`SummarizationMiddleware`, `@before_model`, `@after_model`)
- Added Pattern 23: Recursion Limits + `RemainingSteps` for proactive loop control
- Graph visualization (`draw_mermaid()` / `draw_mermaid_png()`)
- Full `create_agent` signature, middleware imports, managed values in api-reference.md
- Updated dependencies to `langgraph>=1.0.0`

### v1.4.0 — Pre/Post Model Hooks + Migration Notes (2026-03-03)
- Added Pattern 21: Pre/Post Model Hooks for `create_react_agent`
- `pre_model_hook` for message trimming/context management
- `post_model_hook` for guardrails and validation
- Documented `create_react_agent` → `create_agent` migration (LangGraph v1.0)
- Full `create_react_agent` signature in api-reference.md

### v1.3.0 — Fluent Builder Syntax (2026-03-03)
- Added Pattern 20: Chained/Fluent Builder — `StateGraph` methods return `self` for one-liner graphs
- Added fluent syntax note to api-reference.md and guideline #19 to SKILL.md

### v1.2.0 — Modern Streaming + NotRequired (2026-03-03)
- Added Pattern 19: Custom Streaming with `get_stream_writer()`
- Added `get_stream_writer`, `get_config`, `get_store` config utilities to api-reference.md
- Added `NotRequired` state field pattern for optional TypedDict fields
- Updated SKILL.md with custom streaming quick reference and guideline #18

### v1.1.0 — Node Caching + Deferred Nodes (2026-03-03)
- Added Pattern 17: Node Caching with `CachePolicy` + `InMemoryCache`
- Added Pattern 18: Deferred Nodes with `defer=True` for fan-in barriers
- Updated api-reference.md with new imports and `add_node` parameters
- Updated SKILL.md decision guide and quick reference

### v1.0.0 — Final Release (2026-03-03)
- Final audit: 16 patterns, 10 examples, 307-line SKILL.md, all code blocks verified
- Distribution packages verified (zip, tar.gz, combined single-file)

### v0.7.0 — Structure Reconciliation + Polish (2026-03-03)
- Flattened `src/references/` into `src/` — relative links now match installed layout
- Updated install.sh, Makefile, README manual install instructions
- Clean install removes stale files from previous versions

### v0.6.0 — Testing + Production Migration (2026-03-03)
- Added Pattern 15: Testing LangGraph Graphs with pytest
- Added Pattern 16: Production Migration (MemorySaver → PostgresSaver/RedisSaver)
- Added Example 10: Test Suite Template
- Added testing guidelines (#14-15) to SKILL.md

### v0.5.0 — Real-World Agent Examples (2026-03-03)
- Added Example 7: Adaptive RAG Agent with conditional routing and retrieval
- Added Example 8: Self-Correcting Code Generator with reflexion loop
- Added Example 9: Customer Support with Escalation and HITL
- Added RAG and code generation rows to SKILL.md decision guide

### v0.4.0 — Async Patterns + New Checkpointers (2026-03-03)
- Added Pattern 14: Async Graph Execution (`async def` nodes, `ainvoke`, `astream`)
- Added Redis checkpointer imports (`RedisSaver`, `AsyncRedisSaver`) to api-reference.md
- Added Async API section to api-reference.md
- Updated SKILL.md decision guide, quick reference, dependencies, and guidelines

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
