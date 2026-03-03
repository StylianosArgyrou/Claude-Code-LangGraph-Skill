# Changelog

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
