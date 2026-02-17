# Crack Insurance AI Agent
> **Enterprise-grade AI agent for secure, semantic claims processing.**

This project implements a production-ready, secure **Retrieval-Augmented Generation (RAG)** architecture for the insurance industry. The "Crack Insurance" agent empowers adjusters to instantly retrieve complex policy details and similar case precedents using natural language—all without ever exposing the raw database directly to the LLM.

---

## 🎥 Demo

See the agent in action:

[![Watch the video](https://img.youtube.com/vi/CPYr7f_TUFI/hqdefault.jpg)](https://youtu.be/CPYr7f_TUFI)

---

## 🚀 About The Project

**The Problem**: Insurance adjusters spend countless hours manually searching through thousands of PDF policies and articles to answer simple coverage questions like *"Does this policy cover water damage from a burst pipe?"* or *"What is the procedure for wind damage assessment?"*. Keyword searches often fail due to the nuanced language of insurance contracts.

**The Solution**: An intelligent agent that understands *context*, not just keywords. By leveraging **Vector Search** on AlloyDB and a **Secure Tooling Layer**, this agent can semantically match user queries to the exact clauses in a policy document.

**Why I Built This**: I created this project to demonstrate a **secure, scalable pattern for enterprise AI**. Many RAG demos simply give the LLM a connection string to the database, which is a massive security risk. This architecture implements a **Zero-Trust** model where the agent can only interact with data through strictly defined API tools.

---

## 🏗️ System Architecture

The system follows a strict 3-tier architecture to decouple the Agent's reasoning from the Data's storage.

![System Architecture](https://mermaid.ink/img/Z3JhcGggVEQKICAgIFVzZXJbIkFkanVzdGVyIl0gLS0+fE5hdHVyYWwgTGFuZ3VhZ2UgUXVlcnl8IEFnZW50WyJBREsgQWdlbnQgKEdlbWluaSAyLjUpIl0KICAgIHN1YmdyYXBoIFNlY3VyZVpvbmUgWyJTZWN1cmUgWm9uZSJdCiAgICAgICAgQWdlbnQgLS0+fFRvb2wgQ2FsbCAoSFRUUFMpfCBBUElbIlNlY3VyZSBUb29sIEdhdGV3YXkgKENsb3VkIFJ1bikiXQogICAgICAgIEFQSSAtLT58U1FMIFF1ZXJ5fCBEQlsoIkFsbG95REIgUG9zdGdyZXMiKV0KICAgIGVuZAo=)

### 1. Data Layer: AlloyDB (PostgreSQL)
*   **Vector Embeddings**: Uses `pgvector` to store 768-dimensional embeddings of policy abstracts.
*   **Semantic Search**: Enables the database to understand that searching for *"roof leak"* is semantically similar to *"water intrusion from ceiling"*.
*   **Performance**: Indexed with `ivfflat` for high-speed similarity search across large datasets.

### 2. Secure API Layer: MCP Toolbox (Cloud Run)
*   **The "Firewall"**: This is a private, authenticated API service that acts as a gateway between the AI and the Data.
*   **Model Context Protocol (MCP)**: Exposes specific, safe tools like `find_similar_policies` and `get_policy_by_id`.
*   **Security**: The agent has **no DB credentials**. It authenticates to this API, which then executes pre-approved SQL queries.

### 3. Agent Layer: Vertex AI + Python ADK
*   **Reasoning Engine**: Uses **Gemini 2.5 Flash** to parse user intent and orchestrate tool usage.
*   **Context Awareness**: The agent maintains conversation history to ask clarifying questions or refine searches.

---

## ✨ Key Features

*   **🔍 Semantic Understanding**: Queries like *"flood damage in basement"* correctly retrieve policies about *"water backup"* and *"sump pump failure"*, even without exact keyword matches.
*   **🛡️ Zero-Trust Security**: The AI never gets direct SQL access. It must go through the API layer, which validates every request against a strict `tools.yaml` definition.
*   **⚡ Serverless Scalability**: Built on **Cloud Run** and **Vertex AI**, the system scales to zero when not in use and handles high concurrency during peak claims periods.
*   **🔄 Real-time RAG**: As soon as a new policy is added to the database, it is immediately searchable by the agent.

---

## 🛠️ Deployment Guide

Follow these steps to deploy your own instance of the Crack Insurance Agent.

### Prerequisites
*   Google Cloud Project with billing enabled.
*   `gcloud` CLI installed and authenticated.
*   Python 3.10+

### Step 1: Data Layer Setup (AlloyDB)
1.  **Provision AlloyDB**: Create a cluster (`cymbal-cluster`) and instance (`cymbal-instance`) in your project.
2.  **Enable Vector Extension**:
    ```sql
    CREATE EXTENSION IF NOT EXISTS vector;
    GRANT EXECUTE ON FUNCTION embedding TO postgres;
    ```
3.  **Create Schema**:
    Run the SQL scripts in `sql/schema.sql` to create the `customer_records_data` table.
4.  **Generate Embeddings**:
    The system uses the `text-embedding-005` model (via Vertex AI integration) to automatically generate vectors for all policy text.

### Step 2: Secure API Layer (MCP Toolbox)
1.  **Configure Tools**: Define your allowed SQL queries in `tools.yaml`.
    ```yaml
    tools:
      find_similar_policies:
        description: "Finds policies similar to a query."
        statement: "SELECT ... FROM customer_records_data ORDER BY embeddings <=> $1 LIMIT 5"
    ```
2.  **Deploy to Cloud Run**:
    ```bash
    gcloud run deploy toolbox \
        --image=us-central1-docker.pkg.dev/database-toolbox/toolbox/toolbox:latest \
        --service-account=toolbox-identity \
        --set-secrets="/app/tools.yaml=tools:latest"
    ```
    *This creates a private HTTP endpoint that only your agent can reach.*

### Step 3: Agent Layer (Python ADK)
1.  **Install Dependencies**:
    ```bash
    pip install google-adk toolbox-core
    ```
2.  **Connect Agent**:
    Update `agent.py` with your Cloud Run URL. The agent will automatically discover the tools available in the API.
3.  **Run Locally**:
    ```bash
    adk web
    ```

---

## 🔮 Future Improvements

*   **Frontend UI**: Build a React/Next.js dashboard for adjusters to view retrieved policy PDFs side-by-side with the chat.
*   **Multi-Turn Reasoning**: Enhance the agent to handle complex "What if" scenarios by chaining multiple tool calls.
*   **Citation Support**: Modify the agent to cite specific page numbers and clauses in its answers for legal verification.

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.

*Note: This project is a demonstration of enterprise patterns and is not affiliated with any actual insurance provider.*
