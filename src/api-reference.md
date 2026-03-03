# LangGraph API Reference

## Complete Import Map

### Core Graph
```python
from langgraph.graph import StateGraph, START, END
from langgraph.graph import MessagesState
from langgraph.graph.message import add_messages
```

### Functional API
```python
from langgraph.func import entrypoint, task
```

### Types and Commands
```python
from langgraph.types import Send, Command, interrupt
from langgraph.types import RetryPolicy
from langgraph.types import CachePolicy
```

### Node Caching
```python
from langgraph.cache.memory import InMemoryCache
```

### Prebuilt Components
```python
from langgraph.prebuilt import create_react_agent
from langgraph.prebuilt import ToolNode, tools_condition
from langgraph.prebuilt import InjectedState, InjectedStore
```

### Checkpointers (Persistence)
```python
# Development / testing
from langgraph.checkpoint.memory import MemorySaver, InMemorySaver

# Production
from langgraph.checkpoint.postgres import PostgresSaver
from langgraph.checkpoint.postgres.aio import AsyncPostgresSaver
from langgraph.checkpoint.sqlite import SqliteSaver
from langgraph.checkpoint.sqlite.aio import AsyncSqliteSaver
from langgraph.checkpoint.mongodb import MongoDBSaver
from langgraph.checkpoint.mongodb.aio import AsyncMongoDBSaver

# Redis (high-performance production)
from langgraph.checkpoint.redis import RedisSaver
from langgraph.checkpoint.redis.aio import AsyncRedisSaver
```

### Memory Store
```python
from langgraph.store.memory import InMemoryStore
from langgraph.store.base import BaseStore
```

### Messages (from langchain-core)
```python
from langchain_core.messages import (
    HumanMessage,
    AIMessage,
    SystemMessage,
    ToolMessage,
    AnyMessage,
    AIMessageChunk,
    RemoveMessage,
    merge_message_runs,
)
```

### LLM Models
```python
from langchain_openai import ChatOpenAI
from langchain_anthropic import ChatAnthropic
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain.chat_models import init_chat_model  # universal initializer
```

### Tools
```python
from langchain_core.tools import tool  # @tool decorator
from langchain_community.tools.tavily_search import TavilySearchResults
```

### Config Utilities
```python
from langgraph.config import get_stream_writer  # emit custom events from inside nodes
from langgraph.config import get_config          # access config from inside nodes
from langgraph.config import get_store           # access store from inside nodes
```

### Configuration
```python
from langchain_core.runnables import RunnableConfig
from dataclasses import dataclass, field, fields
```

### Pydantic (Structured Output)
```python
from pydantic import BaseModel, Field
```

### Trustcall (Memory Extraction)
```python
from trustcall import create_extractor
```

---

## StateGraph API

### Constructor
```python
builder = StateGraph(
    state_schema,           # TypedDict or Pydantic BaseModel
    config_schema=None,     # Optional dataclass for configurable params
    input=None,             # Optional input schema (subset of state)
    output=None,            # Optional output schema (subset of state)
)
```

### Adding Nodes
```python
# Named node
builder.add_node("name", function)

# Auto-named (uses function name)
builder.add_node(function)

# With cache policy (skip re-execution for same inputs)
builder.add_node("name", function, cache_policy=CachePolicy(ttl=120))

# Deferred (wait for all upstream paths before executing)
builder.add_node("name", function, defer=True)

# Note: add_node, add_edge, add_conditional_edges all return self
# enabling chained/fluent syntax:
# graph = StateGraph(State).add_node(fn).add_edge(START, "fn").compile()
```

### Node Function Signatures
```python
# Basic: just state
def node(state: State) -> dict:
    return {"key": "value"}

# With config
def node(state: State, config: RunnableConfig) -> dict:
    thread_id = config["configurable"]["thread_id"]
    return {"key": "value"}

# With config and store
def node(state: State, config: RunnableConfig, store: BaseStore) -> dict:
    user_id = config["configurable"]["user_id"]
    memories = store.search(("namespace", user_id))
    return {"key": "value"}
```

### Adding Edges
```python
# Sequential
builder.add_edge(START, "node_a")
builder.add_edge("node_a", "node_b")
builder.add_edge("node_b", END)

# Conditional
builder.add_conditional_edges(
    source="node_a",
    path=routing_function,      # returns string node name or END
    path_map=None,              # optional: list of possible targets
)

# Conditional with Send (fan-out)
builder.add_conditional_edges(
    "source_node",
    fan_out_function,           # returns list of Send objects
    ["target_node"],            # list of possible target nodes
)
```

### Compiling
```python
# Basic
graph = builder.compile()

# With node cache
graph = builder.compile(cache=InMemoryCache())

# With checkpointer
graph = builder.compile(checkpointer=MemorySaver())

# With interrupt
graph = builder.compile(
    checkpointer=MemorySaver(),
    interrupt_before=["node_name"],   # pause BEFORE this node
    interrupt_after=["node_name"],    # pause AFTER this node
)

# With store
graph = builder.compile(
    checkpointer=MemorySaver(),
    store=InMemoryStore(),
)
```

### Invoking
```python
# Basic
result = graph.invoke({"key": "value"})

# With config (required for checkpointer)
config = {"configurable": {"thread_id": "1"}}
result = graph.invoke({"key": "value"}, config)

# With user_id for store
config = {"configurable": {"thread_id": "1", "user_id": "user-123"}}
result = graph.invoke({"messages": [HumanMessage("hi")]}, config)

# Resume after interrupt
from langgraph.types import Command
result = graph.invoke(Command(resume="approved"), config)
```

### Streaming
```python
# Stream mode options:
# "values"  - full state after each node
# "updates" - only state changes per node
# "messages" - LLM token chunks + metadata
# "custom"  - user-defined signals
# "debug"   - detailed execution traces

for chunk in graph.stream(input, config, stream_mode="values"):
    chunk["messages"][-1].pretty_print()

for chunk in graph.stream(input, config, stream_mode="updates"):
    print(chunk)

# Multiple modes simultaneously
for chunk in graph.stream(input, config, stream_mode=["messages", "updates"]):
    print(chunk)

# Async streaming
async for chunk in graph.astream(input, config, stream_mode="values"):
    process(chunk)
```

### State Inspection
```python
# Get current state
state = graph.get_state(config)
print(state.values)    # current state dict
print(state.next)      # tuple of next node(s) to run

# Get state history (time travel)
for state in graph.get_state_history(config):
    print(state.values, state.config)

# Update state manually
graph.update_state(config, {"messages": [HumanMessage("injected")]})

# Update state as if a specific node produced it
graph.update_state(config, {"messages": [response]}, as_node="assistant")
```

---

## State Definition Patterns

### Basic TypedDict
```python
class State(TypedDict):
    topic: str
    result: str

# Optional fields (not required on input)
from typing_extensions import TypedDict, NotRequired

class State(TypedDict):
    query: str
    result: NotRequired[str]  # optional — doesn't need to be passed on invoke
```

### With Reducers
```python
from typing import Annotated
from operator import add

class State(TypedDict):
    items: Annotated[list[str], add]     # appends lists
    count: int                            # overwrites (default)
```

### Custom Reducer
```python
def reduce_list(left: list | None, right: list | None) -> list:
    if not left: left = []
    if not right: right = []
    return left + right

class State(TypedDict):
    items: Annotated[list, reduce_list]
```

### MessagesState (Built-in)
```python
from langgraph.graph import MessagesState

# Pre-built with messages key + add_messages reducer
class State(MessagesState):
    extra_field: str
    another_field: int
```

### Input/Output Schemas
```python
class InputState(TypedDict):
    question: str

class OutputState(TypedDict):
    answer: str

class FullState(InputState, OutputState):
    intermediate: str

builder = StateGraph(FullState, input=InputState, output=OutputState)
```

---

## Functional API

### @task — Durable Step
```python
from langgraph.func import task

@task
def my_step(data: str) -> str:
    """Automatically checkpointed. Call with .result() to get return value."""
    return f"processed: {data}"

# With retry policy
@task(retry_policy=RetryPolicy(max_attempts=3))
def resilient_step(data: str) -> str:
    return f"processed: {data}"
```

### @entrypoint — Workflow Entry Point
```python
from langgraph.func import entrypoint, task
from langgraph.checkpoint.memory import InMemorySaver

@task
def step_a(x: str) -> str:
    return x.upper()

@task
def step_b(x: str) -> str:
    return f"Result: {x}"

@entrypoint(checkpointer=InMemorySaver())
def my_workflow(input_data: str) -> str:
    a = step_a(input_data).result()
    return step_b(a).result()

# Invoke
config = {"configurable": {"thread_id": "1"}}
result = my_workflow.invoke("hello", config=config)

# Stream
for chunk in my_workflow.stream("hello", config=config):
    print(chunk)
```

---

## RetryPolicy

```python
from langgraph.types import RetryPolicy

# Default — retries on common network errors
RetryPolicy()

# Custom
RetryPolicy(
    initial_interval=0.5,   # seconds before first retry
    backoff_factor=2.0,     # multiplier per retry
    max_interval=128.0,     # max wait between retries
    max_attempts=3,         # total attempts including first
    jitter=True,            # randomize to avoid thundering herd
    retry_on=Exception,     # exception type(s) to retry on
)

# On a StateGraph node
builder.add_node("node", func, retry_policy=RetryPolicy(max_attempts=3))

# On a Functional API task
@task(retry_policy=RetryPolicy(retry_on=ValueError))
def my_task(data): ...
```

---

## Async API

All sync methods have async counterparts. Use `async def` for nodes and `await` for LLM calls.

### Async Invocation
```python
# ainvoke — async version of invoke
config = {"configurable": {"thread_id": "1"}}
result = await graph.ainvoke({"messages": [("user", "hello")]}, config)
```

### Async Streaming
```python
# astream — async version of stream
async for chunk in graph.astream(input, config, stream_mode="values"):
    chunk["messages"][-1].pretty_print()

# astream with multiple modes
async for chunk in graph.astream(input, config, stream_mode=["updates", "messages"]):
    print(chunk)
```

### Async Node Functions
```python
async def my_node(state: State):
    """Use await for async LLM calls inside async nodes."""
    response = await llm.ainvoke(state["messages"])
    return {"messages": [response]}
```

### Async Checkpointers
```python
# Postgres
from langgraph.checkpoint.postgres.aio import AsyncPostgresSaver
async with AsyncPostgresSaver.from_conn_string(DB_URI) as checkpointer:
    graph = builder.compile(checkpointer=checkpointer)

# Redis
from langgraph.checkpoint.redis.aio import AsyncRedisSaver
async with AsyncRedisSaver.from_conn_string("redis://localhost:6379") as checkpointer:
    graph = builder.compile(checkpointer=checkpointer)

# MongoDB
from langgraph.checkpoint.mongodb.aio import AsyncMongoDBSaver
async with AsyncMongoDBSaver.from_conn_string(DB_URI) as checkpointer:
    graph = builder.compile(checkpointer=checkpointer)

# SQLite
from langgraph.checkpoint.sqlite.aio import AsyncSqliteSaver
async with AsyncSqliteSaver.from_conn_string("checkpoints.db") as checkpointer:
    graph = builder.compile(checkpointer=checkpointer)
```

---

## Tool Definition

### Using @tool decorator
```python
from langchain_core.tools import tool

@tool
def search(query: str) -> str:
    """Search the web for information."""
    return tavily.search(query)
```

### Plain function (auto-detected by LangGraph)
```python
def multiply(a: int, b: int) -> int:
    """Multiply a and b.
    Args:
        a: first int
        b: second int
    """
    return a * b
```

### Binding tools to model
```python
llm = ChatOpenAI(model="gpt-4o")
llm_with_tools = llm.bind_tools(tools, parallel_tool_calls=False)
```

### Structured output
```python
class SearchQuery(BaseModel):
    query: str = Field(description="The search query")
    max_results: int = Field(default=5, description="Max results")

structured_llm = llm.with_structured_output(SearchQuery)
result = structured_llm.invoke("Find info about LangGraph")
# result is a SearchQuery instance
```

---

## Checkpointer Configuration

### Development
```python
from langgraph.checkpoint.memory import MemorySaver
checkpointer = MemorySaver()
```

### SQLite (Lightweight persistence)
```python
from langgraph.checkpoint.sqlite import SqliteSaver
checkpointer = SqliteSaver.from_conn_string("checkpoints.db")

# Async version
from langgraph.checkpoint.sqlite.aio import AsyncSqliteSaver
checkpointer = AsyncSqliteSaver.from_conn_string("checkpoints.db")
```

### PostgreSQL (Production)
```python
from langgraph.checkpoint.postgres import PostgresSaver
DB_URI = "postgresql://user:pass@host:5432/db"
with PostgresSaver.from_conn_string(DB_URI) as checkpointer:
    graph = builder.compile(checkpointer=checkpointer)

# Async version
from langgraph.checkpoint.postgres.aio import AsyncPostgresSaver
async with AsyncPostgresSaver.from_conn_string(DB_URI) as checkpointer:
    graph = builder.compile(checkpointer=checkpointer)
```

### MongoDB
```python
from langgraph.checkpoint.mongodb import MongoDBSaver
DB_URI = "mongodb://localhost:27017"
with MongoDBSaver.from_conn_string(DB_URI) as checkpointer:
    graph = builder.compile(checkpointer=checkpointer)
```

---

## Memory Store API

```python
from langgraph.store.memory import InMemoryStore
store = InMemoryStore()

# Store data with namespace tuple
store.put(
    namespace=("profile", "user-123"),
    key="preferences",
    value={"theme": "dark", "language": "en"}
)

# Search namespace
results = store.search(("profile", "user-123"))
for item in results:
    print(item.key, item.value)

# Get specific item
item = store.get(("profile", "user-123"), "preferences")
print(item.value)

# Delete
store.delete(("profile", "user-123"), "preferences")
```

---

## Configuration Schema

```python
from dataclasses import dataclass, fields
from langchain_core.runnables import RunnableConfig
import os

@dataclass(kw_only=True)
class Configuration:
    user_id: str = "default-user"
    model_name: str = "gpt-4o"
    temperature: float = 0.7

    @classmethod
    def from_runnable_config(cls, config=None):
        configurable = (config["configurable"] if config and "configurable" in config else {})
        values = {
            f.name: os.environ.get(f.name.upper(), configurable.get(f.name))
            for f in fields(cls) if f.init
        }
        return cls(**{k: v for k, v in values.items() if v})

# Usage
builder = StateGraph(State, config_schema=Configuration)
```

---

## Deployment Configuration (langgraph.json)

```json
{
  "$schema": "https://langchain-ai.github.io/langgraph/schemas/langgraph.schema.json",
  "dependencies": ["."],
  "graphs": {
    "agent": "./src/agent.py:graph",
    "chatbot": "./src/chatbot.py:graph"
  },
  "env": ".env"
}
```

### With advanced options
```json
{
  "dependencies": ["."],
  "graphs": {
    "agent": "./agent.py:graph"
  },
  "env": ".env",
  "api_version": "v1",
  "dockerfile_lines": [
    "RUN pip install playwright",
    "RUN playwright install chromium"
  ]
}
```

---

## LangGraph SDK Client (Remote Invocation)

```python
from langgraph_sdk import get_client

client = get_client(url="http://localhost:8123")

# List assistants
assistants = await client.assistants.search()

# Create thread
thread = await client.threads.create()

# Run agent
result = await client.runs.create(
    thread["thread_id"],
    assistant_id="agent",
    input={"messages": [{"role": "user", "content": "Hello"}]},
)

# Stream
async for chunk in client.runs.stream(
    thread["thread_id"],
    assistant_id="agent",
    input={"messages": [{"role": "user", "content": "Hello"}]},
    stream_mode="values",
):
    print(chunk)
```
