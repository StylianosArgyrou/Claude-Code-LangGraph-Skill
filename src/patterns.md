# LangGraph Advanced Patterns

## Pattern 1: ReAct Agent with Tools

The most common agent pattern. The LLM decides which tools to call, observes results, and iterates.

```python
from langchain_openai import ChatOpenAI
from langgraph.graph import MessagesState, StateGraph, START
from langgraph.prebuilt import ToolNode, tools_condition
from langchain_core.messages import SystemMessage

# Define tools
def search(query: str) -> str:
    """Search the web."""
    return "search results..."

def calculator(expression: str) -> str:
    """Calculate math expressions."""
    return str(42)

tools = [search, calculator]
llm = ChatOpenAI(model="gpt-4o").bind_tools(tools, parallel_tool_calls=False)
sys_msg = SystemMessage(content="You are a helpful assistant.")

def assistant(state: MessagesState):
    return {"messages": [llm.invoke([sys_msg] + state["messages"])]}

builder = StateGraph(MessagesState)
builder.add_node("assistant", assistant)
builder.add_node("tools", ToolNode(tools))
builder.add_edge(START, "assistant")
builder.add_conditional_edges("assistant", tools_condition)
builder.add_edge("tools", "assistant")

graph = builder.compile()
```

### Prebuilt ReAct (one-liner)
```python
from langgraph.prebuilt import create_react_agent
from langgraph.checkpoint.memory import MemorySaver

agent = create_react_agent(
    ChatOpenAI(model="gpt-4o"),
    tools=[search, calculator],
    checkpointer=MemorySaver(),
)
```

---

## Pattern 2: Router (Conditional Branching)

Route to different nodes based on LLM classification or state.

```python
from typing import Literal
from pydantic import BaseModel
from langchain_openai import ChatOpenAI
from langchain_core.messages import AIMessage
from langgraph.graph import MessagesState, StateGraph, START, END

llm = ChatOpenAI(model="gpt-4o")

class RouteOutput(BaseModel):
    route: Literal["technical", "general", "escalate"]

class State(MessagesState):
    route: str

def classifier(state: State):
    response = llm.with_structured_output(RouteOutput).invoke(state["messages"])
    return {"route": response.route}

def route_decision(state: State) -> Literal["technical", "general", "escalate"]:
    return state["route"]

def technical_handler(state: State):
    return {"messages": [AIMessage(content="Handling technical query...")]}

def general_handler(state: State):
    return {"messages": [AIMessage(content="Handling general query...")]}

def escalation_handler(state: State):
    return {"messages": [AIMessage(content="Escalating to human agent...")]}

builder = StateGraph(State)
builder.add_node("classifier", classifier)
builder.add_node("technical", technical_handler)
builder.add_node("general", general_handler)
builder.add_node("escalate", escalation_handler)

builder.add_edge(START, "classifier")
builder.add_conditional_edges("classifier", route_decision)
builder.add_edge("technical", END)
builder.add_edge("general", END)
builder.add_edge("escalate", END)

graph = builder.compile()
```

---

## Pattern 3: Human-in-the-Loop with interrupt()

Modern pattern using `interrupt()` and `Command(resume=...)`.

```python
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage, AIMessage
from langgraph.graph import MessagesState, StateGraph, START, END
from langgraph.types import interrupt, Command
from langgraph.checkpoint.memory import MemorySaver

llm = ChatOpenAI(model="gpt-4o")

def plan_node(state: MessagesState):
    plan = llm.invoke(state["messages"])
    return {"messages": [plan]}

def approval_node(state: MessagesState):
    last_message = state["messages"][-1].content
    response = interrupt({
        "question": "Do you approve this plan?",
        "plan": last_message
    })
    if response.get("approved"):
        return Command(goto="execute_node")
    return Command(goto="revise_node")

def execute_node(state: MessagesState):
    return {"messages": [AIMessage(content="Executing plan...")]}

def revise_node(state: MessagesState):
    feedback = state["messages"][-1]  # user feedback from interrupt
    return {"messages": [AIMessage(content=f"Revising based on: {feedback}")]}

builder = StateGraph(MessagesState)
builder.add_node("plan", plan_node)
builder.add_node("approval", approval_node)
builder.add_node("execute", execute_node)
builder.add_node("revise", revise_node)

builder.add_edge(START, "plan")
builder.add_edge("plan", "approval")
builder.add_edge("execute", END)
builder.add_edge("revise", "plan")

graph = builder.compile(checkpointer=MemorySaver())

# Usage
config = {"configurable": {"thread_id": "1"}}
result = graph.invoke({"messages": [HumanMessage("Create a deployment plan")]}, config)
# Graph pauses at approval_node

# Resume with approval
result = graph.invoke(Command(resume={"approved": True}), config)
```

### Legacy pattern: interrupt_before
```python
graph = builder.compile(
    checkpointer=MemorySaver(),
    interrupt_before=["tools"]  # pause before tool execution
)

# Run until interrupt
for event in graph.stream(input, config, stream_mode="values"):
    event["messages"][-1].pretty_print()

# Check state
state = graph.get_state(config)
print(state.next)  # ('tools',)

# Resume
for event in graph.stream(None, config, stream_mode="values"):
    event["messages"][-1].pretty_print()
```

---

## Pattern 4: Map-Reduce with Send API

Fan out work to parallel workers, then aggregate results.

```python
import operator
from typing import Annotated
from typing_extensions import TypedDict
from pydantic import BaseModel
from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph, START, END
from langgraph.types import Send

llm = ChatOpenAI(model="gpt-4o")

class SubjectList(BaseModel):
    subjects: list[str]

class OverallState(TypedDict):
    topic: str
    subjects: list[str]
    results: Annotated[list[str], operator.add]
    final_summary: str

class WorkerState(TypedDict):
    subject: str

def generate_subjects(state: OverallState):
    response = llm.with_structured_output(SubjectList).invoke(
        f"List 5 subtopics for: {state['topic']}"
    )
    return {"subjects": response.subjects}

def fan_out_to_workers(state: OverallState):
    # Send each subject to a parallel worker
    return [Send("worker", {"subject": s}) for s in state["subjects"]]

def worker(state: WorkerState):
    # Each worker processes one subject
    result = llm.invoke(f"Research: {state['subject']}")
    return {"results": [result.content]}

def aggregate(state: OverallState):
    all_results = "\n\n".join(state["results"])
    summary = llm.invoke(f"Summarize these findings:\n{all_results}")
    return {"final_summary": summary.content}

builder = StateGraph(OverallState)
builder.add_node("generate_subjects", generate_subjects)
builder.add_node("worker", worker)
builder.add_node("aggregate", aggregate)

builder.add_edge(START, "generate_subjects")
builder.add_conditional_edges("generate_subjects", fan_out_to_workers, ["worker"])
builder.add_edge("worker", "aggregate")
builder.add_edge("aggregate", END)

graph = builder.compile()
```

---

## Pattern 5: Sub-Graphs

Nested graphs for modular, reusable components.

```python
from typing_extensions import TypedDict
from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph, START, END

llm = ChatOpenAI(model="gpt-4o")

# Child graph - handles research
class ResearchState(TypedDict):
    query: str
    findings: str

def research_node(state: ResearchState):
    result = llm.invoke(f"Research: {state['query']}")
    return {"findings": result.content}

research_builder = StateGraph(ResearchState)
research_builder.add_node("research", research_node)
research_builder.add_edge(START, "research")
research_builder.add_edge("research", END)
research_graph = research_builder.compile()

# Parent graph - orchestrates
class ParentState(TypedDict):
    query: str       # shared key with child
    findings: str    # shared key with child
    final_report: str

def write_report(state: ParentState):
    report = llm.invoke(f"Write report based on: {state['findings']}")
    return {"final_report": report.content}

parent_builder = StateGraph(ParentState)
parent_builder.add_node("research", research_graph)  # sub-graph as node
parent_builder.add_node("report", write_report)
parent_builder.add_edge(START, "research")
parent_builder.add_edge("research", "report")
parent_builder.add_edge("report", END)

parent_graph = parent_builder.compile()
```

---

## Pattern 6: Supervisor Multi-Agent

A supervisor LLM routes tasks to specialized agent sub-graphs.

```python
from typing import Literal
from pydantic import BaseModel
from langchain_openai import ChatOpenAI
from langchain_core.messages import SystemMessage, AIMessage
from langgraph.graph import MessagesState, StateGraph, START, END
from langgraph.types import Command

llm = ChatOpenAI(model="gpt-4o")

class RouteDecision(BaseModel):
    next: Literal["researcher", "coder", "finish"]

class SupervisorState(MessagesState):
    next_agent: str

def supervisor(state: SupervisorState):
    response = llm.with_structured_output(RouteDecision).invoke([
        SystemMessage(content="You are a supervisor. Route to: researcher, coder, or finish."),
        *state["messages"]
    ])
    if response.next == "finish":
        return Command(goto=END)
    return Command(goto=response.next)

def researcher(state: SupervisorState):
    result = llm.invoke([
        SystemMessage(content="You are a research specialist. Provide detailed research."),
        *state["messages"]
    ])
    return {"messages": [AIMessage(content=result.content, name="researcher")]}

def coder(state: SupervisorState):
    result = llm.invoke([
        SystemMessage(content="You are a coding specialist. Write clean, working code."),
        *state["messages"]
    ])
    return {"messages": [AIMessage(content=result.content, name="coder")]}

builder = StateGraph(SupervisorState)
builder.add_node("supervisor", supervisor)
builder.add_node("researcher", researcher)
builder.add_node("coder", coder)

builder.add_edge(START, "supervisor")
builder.add_edge("researcher", "supervisor")
builder.add_edge("coder", "supervisor")

graph = builder.compile()
```

### Using langgraph-supervisor library
```python
from langgraph_supervisor import create_supervisor

supervisor = create_supervisor(
    agents=[researcher_agent, coder_agent],
    model=ChatOpenAI(model="gpt-4o"),
)
graph = supervisor.compile()
```

---

## Pattern 7: Memory Agent with Trustcall

Persistent user profiles and entity extraction across conversations.

```python
import uuid
from typing import Optional
from pydantic import BaseModel, Field
from langchain_openai import ChatOpenAI
from langchain_core.messages import SystemMessage
from langchain_core.runnables import RunnableConfig
from langgraph.graph import MessagesState, StateGraph, START, END
from langgraph.store.memory import InMemoryStore
from langgraph.store.base import BaseStore
from langgraph.checkpoint.memory import MemorySaver
from trustcall import create_extractor

llm = ChatOpenAI(model="gpt-4o")

class Profile(BaseModel):
    name: Optional[str] = None
    location: Optional[str] = None
    interests: list[str] = Field(default_factory=list)

profile_extractor = create_extractor(
    ChatOpenAI(model="gpt-4o"),
    tools=[Profile],
    tool_choice="Profile",
)

def chat_node(state: MessagesState, config: RunnableConfig, store: BaseStore):
    user_id = config["configurable"]["user_id"]
    memories = store.search(("profile", user_id))
    profile = memories[0].value if memories else "No profile yet"

    response = llm.invoke([
        SystemMessage(f"User profile: {profile}"),
        *state["messages"]
    ])
    return {"messages": [response]}

def update_memory(state: MessagesState, config: RunnableConfig, store: BaseStore):
    user_id = config["configurable"]["user_id"]
    existing = store.search(("profile", user_id))
    existing_memories = [(item.key, "Profile", item.value) for item in existing] if existing else None

    result = profile_extractor.invoke({
        "messages": state["messages"],
        "existing": existing_memories
    })

    for r, rmeta in zip(result["responses"], result["response_metadata"]):
        store.put(("profile", user_id), rmeta.get("json_doc_id", str(uuid.uuid4())), r.model_dump(mode="json"))

    return {"messages": []}

builder = StateGraph(MessagesState)
builder.add_node("chat", chat_node)
builder.add_node("update_memory", update_memory)
builder.add_edge(START, "chat")
builder.add_edge("chat", "update_memory")
builder.add_edge("update_memory", END)

graph = builder.compile(
    checkpointer=MemorySaver(),
    store=InMemoryStore()
)
```

---

## Pattern 8: Chatbot with Summarization

Compress long conversations to stay within token limits.

```python
from typing import Literal
from langchain_openai import ChatOpenAI
from langchain_core.messages import SystemMessage, RemoveMessage
from langgraph.graph import MessagesState, StateGraph, START, END

llm = ChatOpenAI(model="gpt-4o")

def chat_node(state: MessagesState):
    response = llm.invoke(state["messages"])
    return {"messages": [response]}

def should_summarize(state: MessagesState) -> Literal["summarize", "chat"]:
    if len(state["messages"]) > 10:
        return "summarize"
    return "chat"

def summarize_conversation(state: MessagesState):
    summary_prompt = f"Summarize this conversation:\n{state['messages']}"
    summary = llm.invoke(summary_prompt)

    # Remove old messages, keep summary
    delete_messages = [RemoveMessage(id=m.id) for m in state["messages"][:-2]]
    return {
        "messages": delete_messages + [SystemMessage(content=f"Summary: {summary.content}")]
    }

builder = StateGraph(MessagesState)
builder.add_node("chat", chat_node)
builder.add_node("summarize", summarize_conversation)
builder.add_edge(START, "chat")
builder.add_conditional_edges("chat", should_summarize)
builder.add_edge("summarize", END)
```

---

## Pattern 9: Streaming with Custom Events

```python
# In your node function, stream custom data
from langgraph.types import StreamWriter

def processing_node(state: State, writer: StreamWriter):
    writer({"progress": "Starting analysis..."})
    # ... do work ...
    writer({"progress": "50% complete"})
    # ... more work ...
    writer({"progress": "Done!"})
    return {"result": "analysis complete"}

# Consume custom stream
for mode, chunk in graph.stream(input, config, stream_mode=["custom", "updates"]):
    if mode == "custom":
        print(f"Progress: {chunk}")
    elif mode == "updates":
        print(f"State update: {chunk}")
```

---

## Pattern 10: Time Travel and State Editing

```python
config = {"configurable": {"thread_id": "1"}}

# Run graph
result = graph.invoke(input, config)

# Browse history
for snapshot in graph.get_state_history(config):
    print(f"Step: {snapshot.config}, Next: {snapshot.next}")

# Replay from a specific checkpoint
old_config = snapshot.config  # pick a historical config
result = graph.invoke(None, old_config)

# Edit state and fork
graph.update_state(config, {"messages": [HumanMessage("Override this")]})
result = graph.invoke(None, config)  # continues from edited state
```

---

## Pattern 11: Double Texting Strategies

When a user sends a new message while the agent is still processing:

```python
# Using LangGraph SDK client
from langgraph_sdk import get_client
client = get_client(url="http://localhost:8123")

# Strategy 1: Reject - refuse new input while busy
run = await client.runs.create(thread_id, assistant_id, input=msg,
    multitask_strategy="reject")

# Strategy 2: Enqueue - queue the new message
run = await client.runs.create(thread_id, assistant_id, input=msg,
    multitask_strategy="enqueue")

# Strategy 3: Interrupt - stop current, start new
run = await client.runs.create(thread_id, assistant_id, input=msg,
    multitask_strategy="interrupt")

# Strategy 4: Rollback - revert to before current run, then start new
run = await client.runs.create(thread_id, assistant_id, input=msg,
    multitask_strategy="rollback")
```

---

## Pattern 12: Functional API with @task and @entrypoint

An alternative to StateGraph — write plain Python functions with durable checkpointing.
Use when you want LangGraph's persistence and retry features without explicit graph construction.

```python
import uuid
from langgraph.func import entrypoint, task
from langgraph.checkpoint.memory import InMemorySaver
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(model="gpt-4o")

@task
def research(topic: str) -> str:
    """Each @task is a durable step — automatically checkpointed."""
    result = llm.invoke(f"Research this topic thoroughly: {topic}")
    return result.content

@task
def summarize(research_results: list[str]) -> str:
    """Combine research into a summary."""
    combined = "\n\n".join(research_results)
    result = llm.invoke(f"Summarize these findings:\n{combined}")
    return result.content

checkpointer = InMemorySaver()

@entrypoint(checkpointer=checkpointer)
def research_workflow(topics: list[str]) -> str:
    """Orchestrate tasks — plain Python control flow, no edges needed."""
    results = []
    for topic in topics:
        result = research(topic).result()  # .result() blocks until done
        results.append(result)
    return summarize(results).result()

# Run it
config = {"configurable": {"thread_id": str(uuid.uuid4())}}
output = research_workflow.invoke(["AI agents", "LangGraph"], config=config)
print(output)
```

### Functional API with Human-in-the-Loop

```python
from langgraph.func import entrypoint, task
from langgraph.types import interrupt, Command
from langgraph.checkpoint.memory import InMemorySaver

@task
def draft_email(topic: str) -> str:
    return f"Draft email about: {topic}"

@entrypoint(checkpointer=InMemorySaver())
def email_workflow(topic: str) -> dict:
    draft = draft_email(topic).result()
    approved = interrupt({"draft": draft, "action": "Approve or reject?"})
    return {"draft": draft, "approved": approved}

# First run — pauses at interrupt
config = {"configurable": {"thread_id": "1"}}
for chunk in email_workflow.stream("quarterly report", config):
    print(chunk)

# Resume with approval
for chunk in email_workflow.stream(Command(resume=True), config):
    print(chunk)
```

---

## Pattern 13: Error Handling with RetryPolicy

Configure automatic retries with exponential backoff for transient failures.

### RetryPolicy on StateGraph Nodes

```python
from langchain_openai import ChatOpenAI
from langchain_core.messages import AIMessage
from langgraph.graph import MessagesState, StateGraph, START, END
from langgraph.types import RetryPolicy

llm = ChatOpenAI(model="gpt-4o")

def unreliable_api_call(state: MessagesState):
    result = llm.invoke(state["messages"])
    return {"messages": [result]}

builder = StateGraph(MessagesState)
builder.add_node(
    "api_call",
    unreliable_api_call,
    retry_policy=RetryPolicy(max_attempts=3, initial_interval=1.0),
)
builder.add_edge(START, "api_call")
builder.add_edge("api_call", END)

graph = builder.compile()
```

### RetryPolicy on Functional API Tasks

```python
from langgraph.func import entrypoint, task
from langgraph.types import RetryPolicy
from langgraph.checkpoint.memory import InMemorySaver

retry_on_value_error = RetryPolicy(retry_on=ValueError)

@task(retry_policy=retry_on_value_error)
def flaky_operation(data: str) -> str:
    # Automatically retries on ValueError
    return f"Processed: {data}"

@entrypoint(checkpointer=InMemorySaver())
def workflow(data: str) -> str:
    return flaky_operation(data).result()
```

### RetryPolicy Parameters

```python
RetryPolicy(
    initial_interval=0.5,   # seconds before first retry
    backoff_factor=2.0,     # multiplier for each subsequent retry
    max_interval=128.0,     # maximum wait between retries
    max_attempts=3,         # total attempts (including first try)
    jitter=True,            # add randomness to avoid thundering herd
    retry_on=Exception,     # exception type(s) to retry on
)
```

---

## Pattern 14: Async Graph Execution

Use `async def` nodes with `ainvoke` and `astream` for non-blocking I/O.
Essential for web servers, high-concurrency applications, and async frameworks like FastAPI.

### Basic Async Graph

```python
import asyncio
from langchain_openai import ChatOpenAI
from langchain_core.messages import SystemMessage
from langgraph.graph import MessagesState, StateGraph, START, END
from langgraph.checkpoint.memory import MemorySaver

llm = ChatOpenAI(model="gpt-4o")

async def research_node(state: MessagesState):
    """Async node — use await for non-blocking LLM calls."""
    response = await llm.ainvoke([
        SystemMessage(content="You are a research assistant."),
        *state["messages"]
    ])
    return {"messages": [response]}

async def summarize_node(state: MessagesState):
    response = await llm.ainvoke([
        SystemMessage(content="Summarize the conversation so far in one sentence."),
        *state["messages"]
    ])
    return {"messages": [response]}

builder = StateGraph(MessagesState)
builder.add_node("research", research_node)
builder.add_node("summarize", summarize_node)
builder.add_edge(START, "research")
builder.add_edge("research", "summarize")
builder.add_edge("summarize", END)

graph = builder.compile(checkpointer=MemorySaver())

# Async invocation
async def main():
    config = {"configurable": {"thread_id": "1"}}
    result = await graph.ainvoke(
        {"messages": [("user", "Research quantum computing")]},
        config
    )
    result["messages"][-1].pretty_print()

asyncio.run(main())
```

### Async Streaming

```python
import asyncio
from langchain_openai import ChatOpenAI
from langgraph.graph import MessagesState, StateGraph, START, END

llm = ChatOpenAI(model="gpt-4o")

async def chat_node(state: MessagesState):
    response = await llm.ainvoke(state["messages"])
    return {"messages": [response]}

builder = StateGraph(MessagesState)
builder.add_node("chat", chat_node)
builder.add_edge(START, "chat")
builder.add_edge("chat", END)
graph = builder.compile()

async def main():
    # Stream full state after each node
    async for chunk in graph.astream(
        {"messages": [("user", "Explain async programming")]},
        stream_mode="values"
    ):
        chunk["messages"][-1].pretty_print()

    # Stream LLM tokens as they arrive
    async for chunk in graph.astream(
        {"messages": [("user", "Write a haiku")]},
        stream_mode="messages"
    ):
        msg, metadata = chunk
        print(msg.content, end="", flush=True)

asyncio.run(main())
```

### Async with Production Checkpointer (Redis)

```python
# pip install langgraph-checkpoint-redis
import asyncio
from langchain_openai import ChatOpenAI
from langgraph.graph import MessagesState, StateGraph, START, END
from langgraph.checkpoint.redis.aio import AsyncRedisSaver

llm = ChatOpenAI(model="gpt-4o")

async def chat_node(state: MessagesState):
    response = await llm.ainvoke(state["messages"])
    return {"messages": [response]}

builder = StateGraph(MessagesState)
builder.add_node("chat", chat_node)
builder.add_edge(START, "chat")
builder.add_edge("chat", END)

async def main():
    async with AsyncRedisSaver.from_conn_string("redis://localhost:6379") as checkpointer:
        graph = builder.compile(checkpointer=checkpointer)
        config = {"configurable": {"thread_id": "1"}}
        result = await graph.ainvoke(
            {"messages": [("user", "Hello!")]},
            config
        )
        result["messages"][-1].pretty_print()

asyncio.run(main())
```

---

## Pattern 15: Testing LangGraph Graphs with pytest

Test graphs by invoking them with known inputs and asserting on the output state.
Mock LLM calls for fast, deterministic unit tests.

### Basic Graph Test

```python
import pytest
from typing_extensions import TypedDict
from langgraph.graph import StateGraph, START, END

class State(TypedDict):
    input: str
    output: str

def process(state: State):
    return {"output": state["input"].upper()}

def build_graph():
    builder = StateGraph(State)
    builder.add_node("process", process)
    builder.add_edge(START, "process")
    builder.add_edge("process", END)
    return builder.compile()

def test_basic_graph():
    graph = build_graph()
    result = graph.invoke({"input": "hello", "output": ""})
    assert result["output"] == "HELLO"

def test_empty_input():
    graph = build_graph()
    result = graph.invoke({"input": "", "output": ""})
    assert result["output"] == ""
```

### Testing with Mocked LLM

```python
import pytest
from unittest.mock import MagicMock, patch
from langchain_core.messages import AIMessage, HumanMessage
from langgraph.graph import MessagesState, StateGraph, START, END

def build_chat_graph(llm):
    def chat(state: MessagesState):
        response = llm.invoke(state["messages"])
        return {"messages": [response]}

    builder = StateGraph(MessagesState)
    builder.add_node("chat", chat)
    builder.add_edge(START, "chat")
    builder.add_edge("chat", END)
    return builder.compile()

def test_chat_with_mock():
    mock_llm = MagicMock()
    mock_llm.invoke.return_value = AIMessage(content="Hello! How can I help?")

    graph = build_chat_graph(mock_llm)
    result = graph.invoke({"messages": [HumanMessage("Hi")]})

    assert len(result["messages"]) == 2
    assert result["messages"][-1].content == "Hello! How can I help?"
    mock_llm.invoke.assert_called_once()
```

### Testing Conditional Routing

```python
import pytest
from typing import Literal
from typing_extensions import TypedDict
from langgraph.graph import StateGraph, START, END

class State(TypedDict):
    value: int
    result: str

def check(state: State):
    return state

def route(state: State) -> Literal["high", "low"]:
    return "high" if state["value"] > 50 else "low"

def high_handler(state: State):
    return {"result": "high_value"}

def low_handler(state: State):
    return {"result": "low_value"}

def build_router():
    builder = StateGraph(State)
    builder.add_node("check", check)
    builder.add_node("high", high_handler)
    builder.add_node("low", low_handler)
    builder.add_edge(START, "check")
    builder.add_conditional_edges("check", route)
    builder.add_edge("high", END)
    builder.add_edge("low", END)
    return builder.compile()

def test_routes_high():
    graph = build_router()
    result = graph.invoke({"value": 75, "result": ""})
    assert result["result"] == "high_value"

def test_routes_low():
    graph = build_router()
    result = graph.invoke({"value": 25, "result": ""})
    assert result["result"] == "low_value"
```

---

## Pattern 16: Production Migration (MemorySaver to PostgresSaver)

Migrate from development checkpointer to production without changing graph logic.

### Development Setup

```python
from langgraph.checkpoint.memory import MemorySaver

# Development — in-memory, no persistence across restarts
graph = builder.compile(checkpointer=MemorySaver())
```

### Production Setup (PostgreSQL)

```python
import os
from langgraph.checkpoint.postgres import PostgresSaver

DB_URI = os.environ["DATABASE_URL"]  # e.g. postgresql://user:pass@host:5432/db

# Sync version
with PostgresSaver.from_conn_string(DB_URI) as checkpointer:
    graph = builder.compile(checkpointer=checkpointer)
    # Use graph within this context...
```

### Production Setup (Redis)

```python
import os
from langgraph.checkpoint.redis import RedisSaver

REDIS_URI = os.environ["REDIS_URL"]  # e.g. redis://localhost:6379

with RedisSaver.from_conn_string(REDIS_URI) as checkpointer:
    graph = builder.compile(checkpointer=checkpointer)
```

### Migration Checklist

```python
# 1. Install production checkpointer
#    pip install langgraph-checkpoint-postgres
#    OR pip install langgraph-checkpoint-redis

# 2. Set environment variable
#    DATABASE_URL=postgresql://user:pass@host:5432/db

# 3. Replace MemorySaver() with production checkpointer:
#    BEFORE: graph = builder.compile(checkpointer=MemorySaver())
#    AFTER:  with PostgresSaver.from_conn_string(DB_URI) as cp:
#                graph = builder.compile(checkpointer=cp)

# 4. Graph definition, nodes, edges — NOTHING changes
# 5. Invocation code — NOTHING changes
# 6. Config format — NOTHING changes: {"configurable": {"thread_id": "..."}}
```

---

## Pattern 17: Node Caching with CachePolicy

Cache node results to skip redundant computation when the same input is seen again.
Useful for expensive LLM calls, API lookups, or any deterministic node.

```python
from typing_extensions import TypedDict
from langgraph.graph import StateGraph, START, END
from langgraph.types import CachePolicy
from langgraph.cache.memory import InMemoryCache

class State(TypedDict):
    query: str
    result: str

def expensive_lookup(state: State):
    """Simulates an expensive operation (API call, LLM, etc.)."""
    import time
    time.sleep(2)  # Expensive work
    return {"result": f"Answer for: {state['query']}"}

# Add node with cache_policy — TTL in seconds
builder = StateGraph(State)
builder.add_node("lookup", expensive_lookup, cache_policy=CachePolicy(ttl=120))
builder.add_edge(START, "lookup")
builder.add_edge("lookup", END)

# Compile with cache backend
graph = builder.compile(cache=InMemoryCache())

# First call — executes the node (slow)
result1 = graph.invoke({"query": "LangGraph", "result": ""})
print(result1["result"])  # "Answer for: LangGraph"

# Second call with same input — returns cached result (fast)
result2 = graph.invoke({"query": "LangGraph", "result": ""})
print(result2["result"])  # "Answer for: LangGraph" (from cache)

# Detect cached results in stream
for chunk in graph.stream({"query": "LangGraph", "result": ""}, stream_mode="updates"):
    for node, update in chunk.items():
        if update.get("__metadata__", {}).get("cached"):
            print(f"{node}: served from cache")
```

---

## Pattern 18: Deferred Nodes

Deferred nodes wait for all upstream paths to complete before executing.
Use for fan-in / consensus patterns where a node should only run after all parallel branches finish.

```python
from typing import Annotated
from typing_extensions import TypedDict
from operator import add
from langgraph.graph import StateGraph, START, END

class State(TypedDict):
    topic: str
    analyses: Annotated[list[str], add]
    summary: str

def analyst_a(state: State):
    return {"analyses": [f"Technical analysis of {state['topic']}"]}

def analyst_b(state: State):
    return {"analyses": [f"Market analysis of {state['topic']}"]}

def analyst_c(state: State):
    return {"analyses": [f"Risk analysis of {state['topic']}"]}

def synthesize(state: State):
    """Only runs after ALL analyst nodes complete (deferred)."""
    combined = " | ".join(state["analyses"])
    return {"summary": f"Synthesis of {len(state['analyses'])} analyses: {combined}"}

builder = StateGraph(State)
builder.add_node("analyst_a", analyst_a)
builder.add_node("analyst_b", analyst_b)
builder.add_node("analyst_c", analyst_c)
# defer=True — waits for all incoming edges before executing
builder.add_node("synthesize", synthesize, defer=True)

# Fan-out from START to all analysts
builder.add_edge(START, "analyst_a")
builder.add_edge(START, "analyst_b")
builder.add_edge(START, "analyst_c")
# All analysts feed into synthesize
builder.add_edge("analyst_a", "synthesize")
builder.add_edge("analyst_b", "synthesize")
builder.add_edge("analyst_c", "synthesize")
builder.add_edge("synthesize", END)

graph = builder.compile()

result = graph.invoke({"topic": "AI startups", "analyses": [], "summary": ""})
print(result["summary"])
# "Synthesis of 3 analyses: Technical analysis... | Market analysis... | Risk analysis..."
assert len(result["analyses"]) == 3
```

---

## Pattern 19: Custom Streaming with get_stream_writer

Emit custom progress events from inside any node using `get_stream_writer()`.
Consume with `stream_mode="custom"` or combine with other modes.

```python
from typing_extensions import TypedDict
from langgraph.graph import StateGraph, START, END
from langgraph.config import get_stream_writer

class State(TypedDict):
    data: str
    result: str

def step_one(state: State):
    writer = get_stream_writer()
    writer({"progress": "Starting processing..."})
    processed = state["data"].upper()
    writer({"progress": "Processing complete", "chars": len(processed)})
    return {"result": processed}

def step_two(state: State):
    writer = get_stream_writer()
    writer({"progress": "Finalizing..."})
    return {"result": f"Final: {state['result']}"}

builder = StateGraph(State)
builder.add_node("step_one", step_one)
builder.add_node("step_two", step_two)
builder.add_edge(START, "step_one")
builder.add_edge("step_one", "step_two")
builder.add_edge("step_two", END)
graph = builder.compile()

# Consume custom events only
for chunk in graph.stream({"data": "hello", "result": ""}, stream_mode="custom"):
    print(f"Custom: {chunk}")

# Combine custom events with state updates
for mode, chunk in graph.stream(
    {"data": "hello", "result": ""},
    stream_mode=["custom", "updates"]
):
    if mode == "custom":
        print(f"Progress: {chunk}")
    else:
        print(f"State update: {chunk}")
```

### Note on Python < 3.11

In async code on Python < 3.11, `get_stream_writer()` won't work due to ContextVar limitations.
Use a `writer` parameter instead:

```python
from langgraph.config import StreamWriter

async def my_node(state: State, writer: StreamWriter):
    writer({"progress": "working..."})
    return {"result": "done"}
```

---

## Pattern 20: Chained (Fluent) Builder Syntax

LangGraph's `StateGraph` methods return `self`, enabling method chaining for concise graph construction.
Both styles produce identical graphs — choose based on readability preference.

### Traditional Style (Recommended for Complex Graphs)

```python
from typing_extensions import TypedDict
from langgraph.graph import StateGraph, START, END

class State(TypedDict):
    text: str

def step_a(state: State):
    return {"text": state["text"] + " -> A"}

def step_b(state: State):
    return {"text": state["text"] + " -> B"}

builder = StateGraph(State)
builder.add_node("step_a", step_a)
builder.add_node("step_b", step_b)
builder.add_edge(START, "step_a")
builder.add_edge("step_a", "step_b")
builder.add_edge("step_b", END)
graph = builder.compile()

result = graph.invoke({"text": "start"})
print(result["text"])  # "start -> A -> B"
```

### Fluent/Chained Style (Concise for Simple Graphs)

```python
from typing_extensions import TypedDict
from langgraph.graph import StateGraph, START, END

class State(TypedDict):
    text: str

def step_a(state: State):
    return {"text": state["text"] + " -> A"}

def step_b(state: State):
    return {"text": state["text"] + " -> B"}

# One-liner — methods return self, enabling chaining
graph = (
    StateGraph(State)
    .add_node("step_a", step_a)
    .add_node("step_b", step_b)
    .add_edge(START, "step_a")
    .add_edge("step_a", "step_b")
    .add_edge("step_b", END)
    .compile()
)

result = graph.invoke({"text": "start"})
print(result["text"])  # "start -> A -> B"
```

---

## Pattern 21: Pre/Post Model Hooks for create_react_agent

Use `pre_model_hook` to modify context before each LLM call (e.g., trim messages).
Use `post_model_hook` to add guardrails, validation, or HITL after each LLM call.

### Pre-Model Hook (Message Trimming)

```python
from langchain_openai import ChatOpenAI
from langchain_core.messages import RemoveMessage
from langgraph.prebuilt import create_react_agent
from langgraph.checkpoint.memory import MemorySaver

def trim_messages(state):
    """Keep only the last 10 messages to manage context window."""
    messages = state["messages"]
    if len(messages) > 10:
        # Option A: Remove old messages from state
        to_remove = [RemoveMessage(id=m.id) for m in messages[:-10]]
        return {"messages": to_remove}
        # Option B: Pass trimmed messages to LLM without modifying state
        # return {"llm_input_messages": messages[-10:]}
    return {"messages": []}

model = ChatOpenAI(model="gpt-4o")
tools = []  # your tools here

agent = create_react_agent(
    model, tools,
    pre_model_hook=trim_messages,
    checkpointer=MemorySaver()
)
```

### Post-Model Hook (Guardrails / Validation)

```python
from langchain_openai import ChatOpenAI
from langgraph.prebuilt import create_react_agent
from langgraph.checkpoint.memory import MemorySaver
from langgraph.types import interrupt

def validate_response(state):
    """Check LLM output and optionally interrupt for human review."""
    last_msg = state["messages"][-1]
    # Example: flag responses that mention sensitive topics
    if "confidential" in last_msg.content.lower():
        response = interrupt({
            "question": "Response mentions confidential info. Approve?",
            "content": last_msg.content
        })
        if response != "yes":
            from langchain_core.messages import AIMessage
            return {"messages": [AIMessage(content="I cannot share that information.")]}
    return {"messages": []}

model = ChatOpenAI(model="gpt-4o")
agent = create_react_agent(
    model, tools=[],
    post_model_hook=validate_response,
    checkpointer=MemorySaver()
)
```

---

## Anti-Patterns to Avoid

1. **Don't store large data in state** — use external storage, pass references
2. **Don't create cycles without exit conditions** — always have a path to END
3. **Don't skip checkpointers for production** — MemorySaver is development only
4. **Don't use mutable default arguments in state** — use `default_factory`
5. **Don't forget thread_id** — every checkpointed invocation needs one
6. **Don't put blocking I/O in nodes without async** — use `astream`/`ainvoke` for async
7. **Don't overwrite list state without reducers** — use `Annotated[list, operator.add]`
8. **Don't nest too deeply** — sub-graphs of sub-graphs get hard to debug
