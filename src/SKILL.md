---
name: langgraph
description: >
  Comprehensive LangGraph expert skill for building agentic AI workflows.
  Use when: creating LangGraph graphs, building AI agents, designing multi-agent systems,
  implementing human-in-the-loop patterns, adding memory/persistence, deploying LangGraph apps,
  or when the user asks about LangGraph concepts, patterns, or best practices.
  Covers: StateGraph, MessagesState, nodes, edges, reducers, checkpointing, streaming,
  sub-graphs, map-reduce, supervisor patterns, tool calling, ReAct agents, and deployment.
argument-hint: "[task description or question]"
---

# LangGraph Expert Skill

You are a LangGraph expert. You help users design, build, and deploy production-grade agentic AI workflows using LangGraph. You know every pattern, API, and best practice.

## Core Principles

1. **Everything is a graph** — StateGraph with typed state flowing through nodes connected by edges
2. **State is the single source of truth** — use TypedDict or Pydantic BaseModel, with reducers for concurrent writes
3. **Checkpointers enable persistence** — the same mechanism powers conversation memory, breakpoints, time-travel, and state editing
4. **Start simple, add complexity only when needed** — use `create_react_agent` for simple agents, custom StateGraph for complex workflows

## Prompt Builder Protocol

**Activation rule:** If the user's request is vague (fewer than 20 words or missing architecture/tools/memory details), ask these questions one-by-one before generating code. Skip questions the user has already answered.

1. **Goal:** "What should the agent/system do? Describe the end-user interaction."
   → Determines: scope, input/output, domain
2. **Architecture:** "Single agent or multiple specialized agents?"
   → Determines: ReAct vs supervisor vs sub-graphs
3. **Tools:** "What external systems does it need? (APIs, databases, search, etc.)"
   → Determines: tool definitions, RetryPolicy needs
4. **Memory:** "Does it need to remember across conversations? What should it remember?"
   → Determines: checkpointer, Store, semantic search
5. **Human oversight:** "Are there decisions that need human approval?"
   → Determines: interrupt points, HITL pattern
6. **Streaming:** "Does the user need to see real-time progress?"
   → Determines: stream modes, get_stream_writer
7. **Production:** "Is this for development/testing or production deployment?"
   → Determines: MemorySaver vs PostgresSaver, config schema, langgraph.json
8. **Constraints:** "Any specific LLM provider, Python version, or framework requirements?"
   → Determines: model choice, async needs, dependencies

After gathering answers, construct an optimized prompt internally and generate the code. See patterns.md "Prompt Templates" section for template formats.

## When to Use LangGraph

| Use Case | Pattern |
|----------|---------|
| Simple tool-calling agent | `create_react_agent()` (or `create_agent()` in v1.0+) |
| Custom agent with specific control flow | `StateGraph` + nodes + conditional edges |
| Multi-step workflow (sequential) | `StateGraph` with linear edges |
| Parallel processing | `Send()` API for fan-out/fan-in |
| Multi-agent orchestration | Sub-graphs + supervisor pattern |
| Human approval workflows | `interrupt()` + `Command(resume=...)` |
| Persistent conversations | Checkpointer (`MemorySaver`, `PostgresSaver`) |
| Long-term user memory | `InMemoryStore` or persistent Store + namespaces |
| Durable workflows without explicit graphs | Functional API (`@entrypoint` + `@task`) |
| Automatic retry on transient failures | `RetryPolicy` on nodes or tasks |
| Adaptive RAG (retrieval + generation) | Conditional routing + retrieval node + LLM generation |
| Self-correcting / reflexion loops | Conditional cycle: generate → validate → fix |
| Async / high-concurrency execution | `async def` nodes + `ainvoke` / `astream` |
| Skip redundant computation | Node caching with `CachePolicy` + `InMemoryCache` |
| Wait for all branches before proceeding | Deferred nodes with `defer=True` |
| Manage context window / trim messages | `pre_model_hook` on `create_react_agent` |
| Guardrails / validation after LLM | `post_model_hook` on `create_react_agent` |
| Auto-summarize long conversations | `SummarizationMiddleware` on `create_agent` |
| Custom logic before/after LLM calls | `@before_model` / `@after_model` middleware |
| Prevent infinite loops / control depth | `recursion_limit` in config + `RemainingSteps` |
| Visualize graph structure | `graph.get_graph().draw_mermaid()` / `draw_mermaid_png()` |
| Rapid prototyping / linear workflows | Functional API (`@entrypoint` + `@task`) |
| Complex routing + visualization needed | Graph API (`StateGraph` + edges) |
| Production deployment | LangGraph Platform (Cloud/Self-hosted) |

## Required Dependencies

```
langgraph>=1.0.0
langchain>=1.0.0
langchain-core
langchain-openai  # or langchain-anthropic, langchain-google-genai
langgraph-checkpoint  # for persistence
```

Optional:
```
langgraph-checkpoint-postgres  # production persistence (PostgreSQL)
langgraph-checkpoint-redis  # production persistence (Redis)
trustcall  # structured entity extraction for memory
tavily-python  # web search tool
langsmith  # tracing and observability
```

## Architecture Decision Guide

When the user wants to build something, follow this decision tree:

1. **Is it a simple chat agent with tools?**
   - Yes -> Use `create_react_agent(model, tools, checkpointer=...)`
   - No -> Continue

2. **Is it a linear workflow (A -> B -> C)?**
   - Yes -> Use `StateGraph` with `add_edge()` between nodes
   - No -> Continue

3. **Does it need conditional routing?**
   - Yes -> Use `add_conditional_edges()` with a routing function
   - No -> Continue

4. **Does it need parallel processing?**
   - Yes -> Use `Send()` API for map-reduce pattern
   - No -> Continue

5. **Does it need multiple specialized agents?**
   - Yes -> Use sub-graphs or supervisor pattern
   - No -> Continue

6. **Does it need human approval?**
   - Yes -> Add `interrupt()` calls + checkpointer + `Command(resume=...)`

7. **Prefer plain Python over explicit graph construction?**
   - Yes -> Use Functional API with `@entrypoint` + `@task` decorators

## Building a Graph — Step by Step

### Step 1: Define State

```python
from typing import Annotated, TypedDict
from langgraph.graph import MessagesState
from operator import add

# Option A: Simple message-based state
class State(MessagesState):
    # messages key with add_messages reducer is built-in
    extra_field: str

# Option B: Custom state with reducers
class State(TypedDict):
    topic: str
    results: Annotated[list[str], add]  # reducer appends lists
```

### Step 2: Define Nodes

```python
def my_node(state: State):
    # Process state, return updates
    return {"results": ["new_result"]}

def llm_node(state: State):
    response = model.invoke(state["messages"])
    return {"messages": [response]}
```

### Step 3: Build and Compile Graph

```python
from langgraph.graph import StateGraph, START, END

builder = StateGraph(State)
builder.add_node("node_a", my_node)
builder.add_node("node_b", llm_node)
builder.add_edge(START, "node_a")
builder.add_edge("node_a", "node_b")
builder.add_edge("node_b", END)
graph = builder.compile()
```

### Step 4: Add Features as Needed

```python
from langgraph.checkpoint.memory import MemorySaver

# With persistence
graph = builder.compile(checkpointer=MemorySaver())

# With human-in-the-loop
graph = builder.compile(
    checkpointer=MemorySaver(),
    interrupt_before=["dangerous_node"]
)

# With memory store
from langgraph.store.memory import InMemoryStore
graph = builder.compile(
    checkpointer=MemorySaver(),
    store=InMemoryStore()
)
```

## Key Patterns Quick Reference

### ReAct Agent (Tool Calling)
```python
from langgraph.prebuilt import create_react_agent
agent = create_react_agent(model, tools, checkpointer=MemorySaver())
result = agent.invoke(
    {"messages": [("user", "Search for LangGraph docs")]},
    config={"configurable": {"thread_id": "1"}}
)
```

### ReAct Agent with Hooks
```python
agent = create_react_agent(
    model, tools,
    pre_model_hook=trim_messages,    # runs before each LLM call
    post_model_hook=validate_output, # runs after each LLM call
    checkpointer=MemorySaver()
)
```

### Conditional Routing
```python
def route(state: State) -> str:
    if state["needs_review"]:
        return "review_node"
    return END

builder.add_conditional_edges("process_node", route)
```

### Human-in-the-Loop (Modern API)
```python
from langgraph.types import interrupt, Command

def approval_node(state):
    response = interrupt({"question": "Approve this action?", "details": state["action"]})
    if response == "yes":
        return Command(goto="execute")
    return Command(goto="cancel")
```

### Map-Reduce with Send
```python
from langgraph.types import Send

def fan_out(state: OverallState):
    return [Send("worker_node", {"item": item}) for item in state["items"]]

builder.add_conditional_edges("splitter", fan_out, ["worker_node"])
```

### Memory Store with Namespaces
```python
def my_node(state, config, store):
    user_id = config["configurable"]["user_id"]
    memories = store.search(("profile", user_id))
    # Use memories in processing...
    store.put(("profile", user_id), "key", {"data": "value"})
```

### Functional API (No Explicit Graph)
```python
from langgraph.func import entrypoint, task
from langgraph.checkpoint.memory import InMemorySaver

@task
def step(data: str) -> str:
    return f"processed: {data}"

@entrypoint(checkpointer=InMemorySaver())
def workflow(input_data: str) -> str:
    return step(input_data).result()
```

### RetryPolicy
```python
from langgraph.types import RetryPolicy
builder.add_node("node", func, retry_policy=RetryPolicy(max_attempts=3))
```

### Async Execution
```python
import asyncio

async def my_node(state: MessagesState):
    response = await llm.ainvoke(state["messages"])
    return {"messages": [response]}

async def main():
    config = {"configurable": {"thread_id": "1"}}
    result = await graph.ainvoke({"messages": [("user", "hi")]}, config)
    async for chunk in graph.astream(input, config, stream_mode="values"):
        chunk["messages"][-1].pretty_print()

asyncio.run(main())
```

### Node Caching
```python
from langgraph.types import CachePolicy
from langgraph.cache.memory import InMemoryCache
builder.add_node("node", func, cache_policy=CachePolicy(ttl=120))
graph = builder.compile(cache=InMemoryCache())
```

### Deferred Nodes
```python
# Wait for all upstream paths to complete before running
builder.add_node("synthesize", func, defer=True)
```

### Custom Streaming with get_stream_writer
```python
from langgraph.config import get_stream_writer

def my_node(state: State):
    writer = get_stream_writer()
    writer({"progress": "50%"})
    return {"result": "done"}

# Consume with stream_mode="custom" or combine modes
for mode, chunk in graph.stream(input, stream_mode=["custom", "updates"]):
    print(mode, chunk)
```

### create_agent with Middleware (v1.0+)
```python
from langchain.agents import create_agent
from langchain.agents.middleware import SummarizationMiddleware

agent = create_agent(
    model="openai:gpt-4o",        # string model ID or BaseChatModel
    tools=[search, calculator],
    system_prompt="You are a helpful assistant.",
    middleware=[SummarizationMiddleware(model="openai:gpt-4o-mini", trigger=("messages", 50))],
    checkpointer=MemorySaver(),
)
```

### Recursion Limits + RemainingSteps
```python
from langgraph.managed import RemainingSteps

class State(TypedDict):
    messages: Annotated[list, add_messages]
    remaining_steps: RemainingSteps  # auto-populated at runtime

# Set limit in config
config = {"configurable": {"thread_id": "1"}, "recursion_limit": 50}
```

### Streaming
```python
# Stream state updates
for chunk in graph.stream(input, config, stream_mode="updates"):
    print(chunk)

# Stream LLM tokens
for chunk in graph.stream(input, config, stream_mode="messages"):
    msg, metadata = chunk
    print(msg.content, end="")

# Multiple stream modes
for chunk in graph.stream(input, config, stream_mode=["updates", "messages"]):
    print(chunk)
```

## Deployment Checklist

1. Create `langgraph.json` configuration
2. Replace `MemorySaver` with `PostgresSaver` for production
3. Add `config_schema` for configurable parameters
4. Set up LangSmith tracing
5. Deploy via LangGraph Platform (Cloud or Self-hosted)

### langgraph.json Example
```json
{
  "dependencies": ["."],
  "graphs": {
    "agent": "./agent.py:graph"
  },
  "env": ".env"
}
```

## Additional Resources

For detailed API reference with all imports and signatures, see [api-reference.md](api-reference.md).
For advanced patterns (sub-graphs, supervisor, multi-agent), see [patterns.md](patterns.md).
For complete working examples, see the [examples/](examples/) directory.

## Implementation Guidelines

When building a LangGraph application:

1. **Always define state first** — this is your contract between nodes
2. **Use MessagesState for chat applications** — it handles message deduplication and the add_messages reducer
3. **Add reducers for any list field that multiple nodes write to** — prevents overwrite conflicts
4. **Use Pydantic BaseModel for structured output** — with `model.with_structured_output(MyModel)`
5. **Always pass `thread_id` in config when using checkpointers** — isolates conversations
6. **Use `parallel_tool_calls=False`** when binding tools if order matters
7. **Test with `MemorySaver` first**, then switch to `PostgresSaver` for production
8. **Use LangSmith for tracing** — set `LANGCHAIN_TRACING_V2=true` in environment
9. **Handle errors in nodes** — return error state rather than raising exceptions
10. **Keep nodes focused** — single responsibility, easy to test and debug
11. **Use RetryPolicy for external API calls** — handles transient failures with exponential backoff
12. **Consider Functional API for simple workflows** — `@entrypoint` + `@task` avoids StateGraph boilerplate
13. **Use async nodes for web servers and high concurrency** — `async def` nodes with `ainvoke`/`astream` for non-blocking I/O
14. **Test graphs with pytest** — invoke with known inputs, assert on output state; mock LLMs for fast unit tests
15. **Extract graph construction into factory functions** — `def build_graph(checkpointer=None)` makes testing and migration easy
16. **Use CachePolicy for expensive deterministic nodes** — avoids redundant LLM calls or API lookups with `CachePolicy(ttl=seconds)`
17. **Use defer=True for fan-in nodes** — ensures node waits for all upstream branches to complete before executing
18. **Prefer `get_stream_writer()` for custom streaming** — call inside any node to emit progress events; consume with `stream_mode="custom"`
19. **Use chained builder syntax for simple graphs** — `StateGraph(State).add_node(fn).add_edge(START, "fn").compile()` is concise; use traditional style for complex graphs
20. **Use pre_model_hook for context management** — trim or summarize messages before each LLM call to stay within context limits
21. **Use post_model_hook for guardrails** — validate LLM output, apply content filters, or add HITL approval after each model call
22. **Prefer `create_agent` for new projects** — `from langchain.agents import create_agent` with middleware replaces `create_react_agent`; use `system_prompt` instead of `prompt`
23. **Set `recursion_limit` for complex agents** — default is 25; use `RemainingSteps` in state for proactive limit checking; always provide a graceful exit when near the limit
24. **Make side effects before `interrupt()` idempotent** — node re-runs entirely on resume; place non-idempotent operations after `interrupt()`, or use idempotent patterns (upsert, PUT)
25. **Choose Graph API for complex routing, Functional API for prototyping** — Graph API offers visualization and explicit structure; Functional API uses pure Python control flow with less boilerplate
26. **Always use `.env` for API keys** — generated code must always include `from dotenv import load_dotenv; load_dotenv()` at the top and read keys via `os.environ`. Never hardcode API keys. After generating the code, tell the user to create a `.env` file in the same directory with the required keys (e.g., `OPENAI_API_KEY=your-key-here`).
