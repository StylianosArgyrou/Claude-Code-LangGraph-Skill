# Changelog

## [1.6.1] - 2026-03-03

### Added
- Example 11: Pattern Showcase — Multi-Agent Research System
  - Demo prompt exercising 11 patterns: supervisor, ReAct, CachePolicy, deferred nodes, get_stream_writer, HITL, memory store, RetryPolicy, RemainingSteps, checkpointer, streaming
  - Isolated subagent successfully generated and ran the full system from the demo prompt
- Updated requirements.txt template to `langgraph>=1.0.0`

## [1.6.0] - 2026-03-03

### Added
- Pattern 24: Interrupt Safety Rules
  - Side effects before `interrupt()` must be idempotent (node re-runs on resume)
  - Place non-idempotent operations after `interrupt()` for single execution
  - Payloads must be JSON-serializable (dict, str, list, int, bool)
  - Resume requires same `thread_id` as the interrupted invocation
  - Summary table of do's and don'ts
- Pattern 25: Graph API vs Functional API Decision Guide
  - When to use Graph API (complex routing, visualization, team collaboration)
  - When to use Functional API (prototyping, linear workflows, Python control flow)
  - Comparison table (control flow, state, visualization, checkpointing, boilerplate)
  - Combining both APIs in one application
- Interrupt Safety Notes section in api-reference.md
- Decision guide rows: rapid prototyping → Functional API, complex routing → Graph API
- Anti-pattern #9: Don't put non-idempotent side effects before interrupt()
- Implementation Guidelines #24-25 (interrupt idempotency, API selection)
- Isolated subagent test: 7/7 pytest tests passed (interrupt safety, functional API, graph API, visualization)

## [1.5.0] - 2026-03-03

### Added
- Pattern 22: `create_agent` with Middleware (LangGraph v1.0+)
  - `from langchain.agents import create_agent` with `system_prompt` parameter
  - String model identifiers: `model="openai:gpt-4o"`
  - `SummarizationMiddleware` for auto-summarizing long conversations
  - Custom `@before_model` and `@after_model` middleware decorators
  - Combining multiple middleware (sequential execution model)
- Pattern 23: Recursion Limits and `RemainingSteps`
  - Configuring `recursion_limit` via config dict (default 25)
  - `from langgraph.managed import RemainingSteps` — auto-populated managed value
  - Proactive limit checking: `if state["remaining_steps"] < 3: return final_answer`
- Graph visualization: `draw_mermaid()` and `draw_mermaid_png()` in patterns + api-reference
- Middleware imports section in api-reference.md (`langchain.agents.middleware`)
- Managed values section in api-reference.md (`RemainingSteps`, `IsLastStep`)
- `create_agent` full signature in api-reference.md
- Decision guide rows: auto-summarize, custom middleware, recursion limits, visualization
- Quick references: create_agent with Middleware, Recursion Limits + RemainingSteps
- Implementation Guidelines #22-23 (prefer create_agent, set recursion_limit)

### Changed
- Updated dependencies: `langgraph>=1.0.0`, `langchain>=1.0.0`
- Marked `create_react_agent` signature as "Legacy (deprecated)" in api-reference.md
- Isolated subagent test: 5/5 pytest tests passed (create_agent, middleware, RemainingSteps, visualization)

## [1.4.0] - 2026-03-03

### Added
- Pattern 21: Pre/Post Model Hooks for `create_react_agent` — context management and guardrails
- `pre_model_hook`: trim/summarize messages before each LLM call; supports `llm_input_messages` for non-destructive trimming
- `post_model_hook`: validate output, add guardrails, or HITL approval after each LLM call
- Full `create_react_agent` signature with all parameters in api-reference.md
- Decision guide rows for context management and guardrails in SKILL.md
- ReAct Agent with Hooks quick reference in SKILL.md
- Implementation Guidelines #20-21 (pre/post hooks usage)

### Changed
- Documented `create_react_agent` deprecation: moved to `from langchain.agents import create_agent` in LangGraph v1.0
- Updated api-reference.md with both new and legacy import paths
- Isolated subagent test: 2/2 pytest tests passed (pre-model trimming + post-model validation, mocked LLM)

## [1.3.0] - 2026-03-03

### Added
- Pattern 20: Chained/Fluent Builder Syntax — `StateGraph` methods return `self` for method chaining
- Fluent syntax note in api-reference.md `add_node` documentation
- Implementation Guideline #19 (use chained syntax for simple graphs)
- Compared traditional vs fluent styles with code examples
- Isolated subagent test: 12/12 pytest tests passed (fluent vs traditional + combined features)

## [1.2.0] - 2026-03-03

### Added
- Pattern 19: Custom Streaming with `get_stream_writer()` — emit progress events from inside any node
- `get_stream_writer`, `get_config`, `get_store` imports in api-reference.md (Config Utilities section)
- `NotRequired` state field pattern in api-reference.md for optional TypedDict fields
- Custom streaming quick reference section in SKILL.md
- Implementation Guideline #18 (prefer `get_stream_writer()` for custom streaming)
- Note on Python < 3.11 async limitation with `StreamWriter` parameter fallback
- Isolated subagent test: 5/5 pytest tests passed (streaming + NotRequired)

## [1.1.0] - 2026-03-03

### Added
- Pattern 17: Node Caching with `CachePolicy` and `InMemoryCache` — skip redundant node execution for same inputs
- Pattern 18: Deferred Nodes with `defer=True` — wait for all upstream paths before executing (fan-in barrier)
- `CachePolicy` and `InMemoryCache` imports in api-reference.md
- `defer=True` and `cache_policy` parameters to `add_node` documentation
- `cache=InMemoryCache()` compile parameter documentation
- Decision guide rows for caching and deferred nodes in SKILL.md
- Quick reference sections for Node Caching and Deferred Nodes in SKILL.md
- Implementation Guidelines #16 (CachePolicy for expensive nodes) and #17 (defer=True for fan-in)
- Isolated subagent test: 1583x caching speedup verified, deferred fan-in confirmed

## [1.0.0] - 2026-03-03

### Release
- Final release audit — all code blocks verified, imports complete, models defined
- SKILL.md: 307 lines (under 500 limit), 14 decision guide rows, 15 implementation guidelines
- 16 patterns: ReAct, Router, HITL, Map-Reduce, Sub-Graphs, Supervisor, Memory, Summarization, Streaming, Time Travel, Double Texting, Functional API, Error Handling, Async, Testing, Production Migration
- 10 complete examples: Chatbot, Research Agent, Multi-Step Approval, Parallel Research, Customer Support, Deployment-Ready, Adaptive RAG, Self-Correcting Code, Support with Escalation, Test Suite Template
- Distribution packages verified (zip, tar.gz, combined single-file)
- Flat file structure: SKILL.md, api-reference.md, patterns.md, examples/

## [0.7.0] - 2026-03-03

### Changed
- Flattened `src/references/` into `src/` — api-reference.md and patterns.md now live alongside SKILL.md
- SKILL.md relative links (`api-reference.md`, `patterns.md`, `examples/`) now match installed layout
- Updated install.sh to clean previous install before copying (removes stale references/ dir)
- Updated Makefile install/package targets for flat structure
- Updated README manual install instructions and file tree

## [0.6.0] - 2026-03-03

### Added
- Pattern 15: Testing LangGraph Graphs with pytest — basic tests, mocked LLM, routing tests
- Pattern 16: Production Migration (MemorySaver → PostgresSaver/RedisSaver) with migration checklist
- Example 10: Test Suite Template — complete pytest test file for graph testing
- Implementation Guidelines #14-15 (pytest testing, factory functions for graphs)

## [0.5.0] - 2026-03-03

### Added
- Example 7: Adaptive RAG Agent — conditional routing between retrieval and direct answer
- Example 8: Self-Correcting Code Generator — reflexion loop with syntax validation
- Example 9: Customer Support with Escalation and HITL — routing + interrupt for human handoff
- RAG and self-correcting code rows in SKILL.md decision guide table

## [0.4.0] - 2026-03-03

### Added
- Pattern 14: Async Graph Execution — `async def` nodes, `ainvoke`, `astream`, async streaming
- Redis checkpointer imports (`RedisSaver`, `AsyncRedisSaver`) in api-reference.md
- Async API section in api-reference.md (`ainvoke`, `astream`, async nodes, async checkpointers)
- Async execution row in SKILL.md decision guide table
- Async quick reference section in SKILL.md
- `langgraph-checkpoint-redis` to optional dependencies in SKILL.md
- Implementation Guideline #13 (async nodes for web servers)
- Async with Redis production checkpointer example in Pattern 14

## [0.3.0] - 2026-03-03

### Added
- Pattern 12: Functional API with `@task` and `@entrypoint` — plain Python workflows with durable checkpointing
- Pattern 13: Error Handling with `RetryPolicy` — automatic retries with exponential backoff
- Functional API section in api-reference.md (`entrypoint`, `task`, imports)
- RetryPolicy section in api-reference.md (parameters, usage on nodes and tasks)
- Functional API and RetryPolicy rows in SKILL.md decision guide table
- Functional API and RetryPolicy quick reference sections in SKILL.md
- Architecture Decision Guide step 7 (Functional API)
- Implementation Guidelines #11 (RetryPolicy) and #12 (Functional API)

## [0.2.0] - 2026-03-03

### Fixed
- Pattern 2 (Router): Added `RouteOutput` model, `llm` init, handler stubs, all imports
- Pattern 3 (HITL): Added `HumanMessage`/`AIMessage` imports, `llm` init
- Pattern 4 (Map-Reduce): Added `SubjectList` model, `TypedDict`, `StateGraph` imports, `llm` init
- Pattern 5 (Sub-Graphs): Added `TypedDict`, `ChatOpenAI`, `StateGraph` imports, `llm` init
- Pattern 6 (Supervisor): Added `RouteDecision` model, replaced undefined agent stubs with inline LLM calls
- Pattern 7 (Memory): Added `uuid`, `Optional`, `BaseModel`, `Field`, `RunnableConfig`, `BaseStore`, `llm`
- Pattern 8 (Summarization): Added `Literal` import, defined `llm` and `chat_node`
- Example 3: Replaced invalid `**Command(goto=...)` with `Command(goto=..., update={...})`
- CHANGELOG version header fixed from `[1.0.0]` to `[0.1.0]`

## [0.1.0] - 2026-03-03

### Added
- Initial release of LangGraph skill for Claude Code
- Core SKILL.md with architecture decision guide and quick reference patterns
- API reference covering all imports, StateGraph API, state definitions, tools, checkpointers, store, config schemas, deployment, and SDK client
- 11 advanced patterns with full code examples
- 6 complete working examples
- Installation via `make install`, `./install.sh`, or manual copy
- GitHub Actions workflow for automated releases
