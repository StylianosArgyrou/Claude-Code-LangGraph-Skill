# LangGraph Complete Working Examples

## Example 1: Simple Chatbot with Memory

A basic chatbot that remembers conversation history across turns.

```python
from langchain_openai import ChatOpenAI
from langgraph.graph import MessagesState, StateGraph, START
from langgraph.checkpoint.memory import MemorySaver
from langchain_core.messages import HumanMessage

model = ChatOpenAI(model="gpt-4o")

def chatbot(state: MessagesState):
    return {"messages": [model.invoke(state["messages"])]}

builder = StateGraph(MessagesState)
builder.add_node("chatbot", chatbot)
builder.add_edge(START, "chatbot")

graph = builder.compile(checkpointer=MemorySaver())

# Conversation
config = {"configurable": {"thread_id": "user-1"}}

response = graph.invoke(
    {"messages": [HumanMessage("Hi, I'm Alice")]}, config
)
print(response["messages"][-1].content)

response = graph.invoke(
    {"messages": [HumanMessage("What's my name?")]}, config
)
print(response["messages"][-1].content)  # Knows it's Alice
```

---

## Example 2: Research Agent with Web Search

An agent that searches the web and synthesizes findings.

```python
from langchain_openai import ChatOpenAI
from langchain_community.tools.tavily_search import TavilySearchResults
from langgraph.graph import MessagesState, StateGraph, START
from langgraph.prebuilt import ToolNode, tools_condition
from langgraph.checkpoint.memory import MemorySaver
from langchain_core.messages import SystemMessage

search_tool = TavilySearchResults(max_results=3)
tools = [search_tool]

model = ChatOpenAI(model="gpt-4o").bind_tools(tools)
sys_msg = SystemMessage(content="You are a research assistant. Use search to find accurate information.")

def assistant(state: MessagesState):
    return {"messages": [model.invoke([sys_msg] + state["messages"])]}

builder = StateGraph(MessagesState)
builder.add_node("assistant", assistant)
builder.add_node("tools", ToolNode(tools))
builder.add_edge(START, "assistant")
builder.add_conditional_edges("assistant", tools_condition)
builder.add_edge("tools", "assistant")

graph = builder.compile(checkpointer=MemorySaver())
```

---

## Example 3: Multi-Step Workflow with Approval

A content creation pipeline with human approval gates.

```python
from typing import Annotated, Literal
from typing_extensions import TypedDict
from operator import add
from langgraph.graph import StateGraph, START, END
from langgraph.types import interrupt, Command
from langgraph.checkpoint.memory import MemorySaver
from langchain_openai import ChatOpenAI

model = ChatOpenAI(model="gpt-4o")

class ContentState(TypedDict):
    topic: str
    outline: str
    draft: str
    feedback: str
    final: str

def create_outline(state: ContentState):
    result = model.invoke(f"Create an outline for: {state['topic']}")
    return {"outline": result.content}

def review_outline(state: ContentState):
    response = interrupt({
        "step": "outline_review",
        "outline": state["outline"],
        "question": "Approve this outline or provide feedback?"
    })
    if response.get("approved"):
        return Command(goto="write_draft")
    return {"feedback": response.get("feedback", ""), **Command(goto="create_outline")}

def write_draft(state: ContentState):
    result = model.invoke(
        f"Write content based on this outline:\n{state['outline']}"
        + (f"\nIncorporate feedback: {state['feedback']}" if state.get("feedback") else "")
    )
    return {"draft": result.content}

def review_draft(state: ContentState):
    response = interrupt({
        "step": "draft_review",
        "draft": state["draft"],
        "question": "Approve final draft?"
    })
    if response.get("approved"):
        return {"final": state["draft"]}
    return {"feedback": response.get("feedback", ""), **Command(goto="write_draft")}

builder = StateGraph(ContentState)
builder.add_node("create_outline", create_outline)
builder.add_node("review_outline", review_outline)
builder.add_node("write_draft", write_draft)
builder.add_node("review_draft", review_draft)

builder.add_edge(START, "create_outline")
builder.add_edge("create_outline", "review_outline")
builder.add_edge("write_draft", "review_draft")
builder.add_edge("review_draft", END)

graph = builder.compile(checkpointer=MemorySaver())
```

---

## Example 4: Parallel Research with Map-Reduce

Research multiple topics in parallel and synthesize results.

```python
import operator
from typing import Annotated
from typing_extensions import TypedDict
from pydantic import BaseModel
from langgraph.types import Send
from langgraph.graph import StateGraph, START, END
from langchain_openai import ChatOpenAI

model = ChatOpenAI(model="gpt-4o")

class Topics(BaseModel):
    topics: list[str]

class OverallState(TypedDict):
    question: str
    topics: list[str]
    research: Annotated[list[str], operator.add]
    synthesis: str

class ResearchState(TypedDict):
    topic: str

def decompose(state: OverallState):
    result = model.with_structured_output(Topics).invoke(
        f"Break this question into 3-5 research topics: {state['question']}"
    )
    return {"topics": result.topics}

def fan_out(state: OverallState):
    return [Send("research", {"topic": t}) for t in state["topics"]]

def research(state: ResearchState):
    result = model.invoke(f"Research this topic thoroughly: {state['topic']}")
    return {"research": [f"## {state['topic']}\n{result.content}"]}

def synthesize(state: OverallState):
    all_research = "\n\n".join(state["research"])
    result = model.invoke(
        f"Synthesize these research findings into a coherent answer "
        f"to: {state['question']}\n\nFindings:\n{all_research}"
    )
    return {"synthesis": result.content}

builder = StateGraph(OverallState)
builder.add_node("decompose", decompose)
builder.add_node("research", research)
builder.add_node("synthesize", synthesize)

builder.add_edge(START, "decompose")
builder.add_conditional_edges("decompose", fan_out, ["research"])
builder.add_edge("research", "synthesize")
builder.add_edge("synthesize", END)

graph = builder.compile()

# Usage
result = graph.invoke({"question": "What are the implications of quantum computing on cryptography?"})
print(result["synthesis"])
```

---

## Example 5: Customer Support Agent with Routing

Route customer queries to specialized handlers.

```python
from typing import Literal
from pydantic import BaseModel
from langgraph.graph import MessagesState, StateGraph, START, END
from langchain_openai import ChatOpenAI
from langchain_core.messages import SystemMessage, AIMessage

model = ChatOpenAI(model="gpt-4o")

class RouteOutput(BaseModel):
    department: Literal["billing", "technical", "general"]

class SupportState(MessagesState):
    department: str

def classify(state: SupportState):
    result = model.with_structured_output(RouteOutput).invoke([
        SystemMessage("Classify this customer query into: billing, technical, or general"),
        *state["messages"]
    ])
    return {"department": result.department}

def route(state: SupportState) -> str:
    return state["department"]

def billing_handler(state: SupportState):
    response = model.invoke([
        SystemMessage("You are a billing specialist. Help with payment, invoices, and subscription issues."),
        *state["messages"]
    ])
    return {"messages": [response]}

def technical_handler(state: SupportState):
    response = model.invoke([
        SystemMessage("You are a technical support specialist. Help with bugs, setup, and technical issues."),
        *state["messages"]
    ])
    return {"messages": [response]}

def general_handler(state: SupportState):
    response = model.invoke([
        SystemMessage("You are a general support agent. Help with general inquiries."),
        *state["messages"]
    ])
    return {"messages": [response]}

builder = StateGraph(SupportState)
builder.add_node("classify", classify)
builder.add_node("billing", billing_handler)
builder.add_node("technical", technical_handler)
builder.add_node("general", general_handler)

builder.add_edge(START, "classify")
builder.add_conditional_edges("classify", route)
builder.add_edge("billing", END)
builder.add_edge("technical", END)
builder.add_edge("general", END)

graph = builder.compile()
```

---

## Example 6: Deployment-Ready Agent

Full production agent with configuration, store, and checkpointer.

```python
# configuration.py
import os
from dataclasses import dataclass, fields
from typing import Any, Optional
from langchain_core.runnables import RunnableConfig

@dataclass(kw_only=True)
class Configuration:
    user_id: str = "default-user"
    model_name: str = "gpt-4o"
    system_prompt: str = "You are a helpful assistant."

    @classmethod
    def from_runnable_config(cls, config: Optional[RunnableConfig] = None) -> "Configuration":
        configurable = (config["configurable"] if config and "configurable" in config else {})
        values = {
            f.name: os.environ.get(f.name.upper(), configurable.get(f.name))
            for f in fields(cls) if f.init
        }
        return cls(**{k: v for k, v in values.items() if v})

# agent.py
from langgraph.graph import MessagesState, StateGraph, START, END
from langgraph.store.base import BaseStore
from langchain_openai import ChatOpenAI
from langchain_core.messages import SystemMessage

def agent_node(state: MessagesState, config: RunnableConfig, store: BaseStore):
    cfg = Configuration.from_runnable_config(config)
    model = ChatOpenAI(model=cfg.model_name)

    # Load user memories
    memories = store.search(("memories", cfg.user_id))
    memory_context = "\n".join(m.value.get("content", "") for m in memories)

    response = model.invoke([
        SystemMessage(f"{cfg.system_prompt}\n\nUser context: {memory_context}"),
        *state["messages"]
    ])
    return {"messages": [response]}

builder = StateGraph(MessagesState, config_schema=Configuration)
builder.add_node("agent", agent_node)
builder.add_edge(START, "agent")
builder.add_edge("agent", END)

graph = builder.compile()

# langgraph.json
# {
#   "dependencies": ["."],
#   "graphs": {
#     "agent": "./agent.py:graph"
#   },
#   "env": ".env"
# }
```

---

## Project Scaffolding Template

When creating a new LangGraph project from scratch:

```
my-langgraph-project/
├── src/
│   ├── __init__.py
│   ├── agent.py           # Main graph definition
│   ├── configuration.py   # Config schema (if deploying)
│   ├── nodes.py           # Node functions
│   ├── state.py           # State definitions
│   └── tools.py           # Tool definitions
├── tests/
│   └── test_agent.py
├── langgraph.json          # Deployment config
├── requirements.txt
├── .env                    # API keys (never commit)
└── pyproject.toml
```

### requirements.txt template
```
langgraph>=0.2.0
langchain-core>=0.3.0
langchain-openai>=0.2.0
langgraph-checkpoint>=2.0.0
# Production:
# langgraph-checkpoint-postgres>=2.0.0
# Optional:
# trustcall
# tavily-python
# langsmith
```
