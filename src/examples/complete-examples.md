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
    return Command(goto="create_outline", update={"feedback": response.get("feedback", "")})

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
    return Command(goto="write_draft", update={"feedback": response.get("feedback", "")})

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

## Example 7: Adaptive RAG Agent

Routes queries to retrieval or direct answer based on whether the question needs external context.
Combines conditional routing with retrieval-augmented generation.

```python
from typing import Literal
from typing_extensions import TypedDict
from pydantic import BaseModel
from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph, START, END

model = ChatOpenAI(model="gpt-4o")

# -- Simulated knowledge base (replace with real vector store) --
KNOWLEDGE_BASE = {
    "pricing": "Our Basic plan is $10/mo, Pro is $25/mo, Enterprise is custom.",
    "refund": "Refunds are available within 30 days of purchase.",
    "api": "Our API supports REST and GraphQL. Rate limit is 1000 req/min.",
}

def retrieve(query: str) -> str:
    """Simple keyword retrieval — replace with vector similarity search."""
    for key, value in KNOWLEDGE_BASE.items():
        if key in query.lower():
            return value
    return "No relevant documents found."

# -- State and Models --

class RouteDecision(BaseModel):
    route: Literal["retrieve", "direct"]
    reasoning: str

class RAGState(TypedDict):
    question: str
    route: str
    context: str
    answer: str

# -- Nodes --

def classify_query(state: RAGState):
    decision = model.with_structured_output(RouteDecision).invoke(
        f"Should this question use document retrieval or be answered directly?\n"
        f"Question: {state['question']}\n"
        f"Route to 'retrieve' if it asks about pricing, refunds, or API details."
    )
    return {"route": decision.route}

def route_query(state: RAGState) -> Literal["retrieve_docs", "direct_answer"]:
    return "retrieve_docs" if state["route"] == "retrieve" else "direct_answer"

def retrieve_docs(state: RAGState):
    context = retrieve(state["question"])
    return {"context": context}

def generate_answer(state: RAGState):
    context = state.get("context", "")
    prompt = f"Answer this question: {state['question']}"
    if context:
        prompt = f"Using this context:\n{context}\n\n{prompt}"
    result = model.invoke(prompt)
    return {"answer": result.content}

def direct_answer(state: RAGState):
    result = model.invoke(f"Answer this question directly: {state['question']}")
    return {"answer": result.content}

# -- Graph --

builder = StateGraph(RAGState)
builder.add_node("classify", classify_query)
builder.add_node("retrieve_docs", retrieve_docs)
builder.add_node("generate_answer", generate_answer)
builder.add_node("direct_answer", direct_answer)

builder.add_edge(START, "classify")
builder.add_conditional_edges("classify", route_query)
builder.add_edge("retrieve_docs", "generate_answer")
builder.add_edge("generate_answer", END)
builder.add_edge("direct_answer", END)

graph = builder.compile()

# Usage
result = graph.invoke({"question": "What is the pricing for the Pro plan?"})
print(result["answer"])
```

---

## Example 8: Self-Correcting Code Generator

Generates code, validates it, and loops back to fix errors until correct.
Demonstrates the reflexion/self-correction pattern with conditional cycles.

```python
from typing import Literal
from typing_extensions import TypedDict
from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph, START, END

model = ChatOpenAI(model="gpt-4o")

class CodeState(TypedDict):
    task: str
    code: str
    error: str
    attempts: int

def generate_code(state: CodeState):
    prompt = f"Write a Python function for: {state['task']}\n"
    if state.get("error"):
        prompt += f"Previous attempt had this error:\n{state['error']}\nFix the code."
    if state.get("code"):
        prompt += f"\nPrevious code:\n{state['code']}"
    prompt += "\nReturn ONLY the Python code, no explanations."
    result = model.invoke(prompt)
    return {"code": result.content, "attempts": state.get("attempts", 0) + 1}

def validate_code(state: CodeState):
    """Try to compile the code to check for syntax errors."""
    code = state["code"]
    # Strip markdown code fences if present
    if "```python" in code:
        code = code.split("```python")[1].split("```")[0]
    elif "```" in code:
        code = code.split("```")[1].split("```")[0]
    try:
        compile(code.strip(), "<string>", "exec")
        return {"error": ""}
    except SyntaxError as e:
        return {"error": f"SyntaxError: {e}"}

def should_retry(state: CodeState) -> Literal["generate", "__end__"]:
    if state.get("error") and state["attempts"] < 3:
        return "generate"
    return END

builder = StateGraph(CodeState)
builder.add_node("generate", generate_code)
builder.add_node("validate", validate_code)

builder.add_edge(START, "generate")
builder.add_edge("generate", "validate")
builder.add_conditional_edges("validate", should_retry)

graph = builder.compile()

# Usage
result = graph.invoke({"task": "fibonacci sequence generator", "code": "", "error": "", "attempts": 0})
print(f"Generated in {result['attempts']} attempt(s):")
print(result["code"])
```

---

## Example 9: Customer Support with Escalation and HITL

Combines routing, specialized handlers, and human-in-the-loop escalation.
Uses `interrupt()` for agent-to-human handoff when the AI cannot resolve an issue.

```python
from typing import Literal
from pydantic import BaseModel
from langchain_openai import ChatOpenAI
from langchain_core.messages import SystemMessage, AIMessage
from langgraph.graph import MessagesState, StateGraph, START, END
from langgraph.types import interrupt, Command
from langgraph.checkpoint.memory import MemorySaver

model = ChatOpenAI(model="gpt-4o")

class TriageDecision(BaseModel):
    department: Literal["billing", "technical", "escalate"]
    confidence: float

class SupportState(MessagesState):
    department: str
    confidence: float
    resolved: bool

def triage(state: SupportState):
    decision = model.with_structured_output(TriageDecision).invoke([
        SystemMessage(
            "Classify this support ticket. Use 'escalate' if the issue is "
            "complex, involves account security, or you're unsure (confidence < 0.7)."
        ),
        *state["messages"]
    ])
    return {"department": decision.department, "confidence": decision.confidence}

def route_ticket(state: SupportState) -> Literal["billing", "technical", "escalate"]:
    if state["confidence"] < 0.7:
        return "escalate"
    return state["department"]

def billing_handler(state: SupportState):
    response = model.invoke([
        SystemMessage("You are a billing specialist. Resolve payment and invoice issues."),
        *state["messages"]
    ])
    return {"messages": [response], "resolved": True}

def technical_handler(state: SupportState):
    response = model.invoke([
        SystemMessage("You are a technical specialist. Resolve bugs and setup issues."),
        *state["messages"]
    ])
    return {"messages": [response], "resolved": True}

def escalate_to_human(state: SupportState):
    """Pause execution and hand off to a human agent."""
    human_response = interrupt({
        "reason": "This ticket requires human attention",
        "department": state["department"],
        "confidence": state["confidence"],
        "conversation": [m.content for m in state["messages"]],
        "action": "Please provide a resolution message for the customer."
    })
    return {
        "messages": [AIMessage(content=human_response)],
        "resolved": True,
    }

builder = StateGraph(SupportState)
builder.add_node("triage", triage)
builder.add_node("billing", billing_handler)
builder.add_node("technical", technical_handler)
builder.add_node("escalate", escalate_to_human)

builder.add_edge(START, "triage")
builder.add_conditional_edges("triage", route_ticket)
builder.add_edge("billing", END)
builder.add_edge("technical", END)
builder.add_edge("escalate", END)

graph = builder.compile(checkpointer=MemorySaver())

# Usage — normal ticket
config = {"configurable": {"thread_id": "ticket-1"}}
result = graph.invoke(
    {"messages": [("user", "I was charged twice for my subscription")]},
    config
)
print(result["messages"][-1].content)

# Usage — escalated ticket (pauses at interrupt)
config2 = {"configurable": {"thread_id": "ticket-2"}}
result = graph.invoke(
    {"messages": [("user", "Someone accessed my account without permission")]},
    config2
)
# If interrupted, resume with human agent's response:
# result = graph.invoke(Command(resume="We've secured your account and reset your password."), config2)
```

---

## Example 10: Test Suite Template

A pytest test suite template for testing LangGraph graphs.
Tests graph structure, node logic, routing, and checkpointer integration.

```python
"""tests/test_agent.py — pytest test suite for a LangGraph agent."""
import pytest
from unittest.mock import MagicMock
from typing import Literal
from typing_extensions import TypedDict
from langchain_core.messages import AIMessage, HumanMessage
from langgraph.graph import MessagesState, StateGraph, START, END
from langgraph.checkpoint.memory import MemorySaver


# ── Graph under test ──────────────────────────────────────────────

class TaskState(TypedDict):
    task: str
    category: str
    result: str

def categorize(state: TaskState):
    task = state["task"].lower()
    if "bug" in task or "error" in task:
        return {"category": "fix"}
    return {"category": "feature"}

def route_category(state: TaskState) -> Literal["fix_handler", "feature_handler"]:
    return "fix_handler" if state["category"] == "fix" else "feature_handler"

def fix_handler(state: TaskState):
    return {"result": f"Fixing: {state['task']}"}

def feature_handler(state: TaskState):
    return {"result": f"Building: {state['task']}"}

def build_task_graph(checkpointer=None):
    builder = StateGraph(TaskState)
    builder.add_node("categorize", categorize)
    builder.add_node("fix_handler", fix_handler)
    builder.add_node("feature_handler", feature_handler)
    builder.add_edge(START, "categorize")
    builder.add_conditional_edges("categorize", route_category)
    builder.add_edge("fix_handler", END)
    builder.add_edge("feature_handler", END)
    return builder.compile(checkpointer=checkpointer)


# ── Tests ─────────────────────────────────────────────────────────

class TestTaskGraph:
    def test_routes_bug_to_fix(self):
        graph = build_task_graph()
        result = graph.invoke({"task": "Fix bug in login", "category": "", "result": ""})
        assert result["category"] == "fix"
        assert "Fixing:" in result["result"]

    def test_routes_feature_to_feature(self):
        graph = build_task_graph()
        result = graph.invoke({"task": "Add dark mode", "category": "", "result": ""})
        assert result["category"] == "feature"
        assert "Building:" in result["result"]

    def test_error_keyword_routes_to_fix(self):
        graph = build_task_graph()
        result = graph.invoke({"task": "Error in payment", "category": "", "result": ""})
        assert result["category"] == "fix"

    def test_with_checkpointer(self):
        graph = build_task_graph(checkpointer=MemorySaver())
        config = {"configurable": {"thread_id": "test-1"}}
        result = graph.invoke(
            {"task": "Add search feature", "category": "", "result": ""},
            config
        )
        assert result["result"] == "Building: Add search feature"

        # Verify state was saved
        state = graph.get_state(config)
        assert state.values["result"] == "Building: Add search feature"


class TestChatGraph:
    def test_with_mock_llm(self):
        mock_llm = MagicMock()
        mock_llm.invoke.return_value = AIMessage(content="Mocked response")

        def chat(state: MessagesState):
            return {"messages": [mock_llm.invoke(state["messages"])]}

        builder = StateGraph(MessagesState)
        builder.add_node("chat", chat)
        builder.add_edge(START, "chat")
        builder.add_edge("chat", END)
        graph = builder.compile()

        result = graph.invoke({"messages": [HumanMessage("Hello")]})
        assert result["messages"][-1].content == "Mocked response"
        mock_llm.invoke.assert_called_once()


# Run with: pytest tests/test_agent.py -v
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
