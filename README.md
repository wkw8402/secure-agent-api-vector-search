# secure-agent-api-vector-search
**Build a foundational AI agent with secure database access (GCP lab recap + reproducible repo)**

This repo documents (and partially re-creates) a production-style pattern for **letting an AI agent query enterprise data safely**—without giving the agent direct access to a production database.

You’ll see a clean **three-tier architecture**:

1) **Data Layer** (AlloyDB + vector search)  
2) **Secure API Layer** (MCP Toolbox on Cloud Run, private)  
3) **Agent Layer** (ADK agent using Gemini via Vertex AI)

I originally built this in a time-limited Google Cloud Skills Boost lab. The lab environment is ephemeral, so this repo preserves the steps, configs, and code structure (plus a demo video).

---

# Agent Vector Search Demo

* **Video demo**:

[![Watch the video](https://img.youtube.com/vi/CPYr7f_TUFI/hqdefault.jpg)](https://youtu.be/CPYr7f_TUFI)

---

## Architecture at a glance

```

User Question
|
v
ADK Agent (Gemini via Vertex AI)
|
| HTTPS (authenticated)
v
Cloud Run: MCP Toolbox (private “tool gateway”)
|
| private networking (VPC connector)
v
AlloyDB (Postgres + vector extension + embeddings)

```

**Key idea:** the agent never touches the DB directly.  
It can only call **approved tools** (SQL queries) exposed by a secure API.

---

## Repo contents
You can structure the repo like this:

```

.
├── README.md
├── tools.yaml                      # tool “blueprint” used by MCP Toolbox
├── agent/
│   ├── agent.py                    # ADK agent definition
│   ├── requirements.txt
│   └── .env.example
├── sql/
│   ├── 01_extensions.sql
│   ├── 02_schema.sql
│   ├── 03_seed_data.sql
│   ├── 04_embeddings.sql
│   └── 05_vector_index.sql
├── demo/
│   └── demo.mp4                    # optional: your recorded demo
└── screenshots/                    # optional: UI screenshots from lab

````

> ⚠️ Don’t commit real secrets. Use `.env.example` and Secret Manager in real deployments.

---

# Chapter 1 — Data Layer (AlloyDB + vector search)

## 1.1 Provision / verify AlloyDB is ready
In the lab, an AlloyDB cluster and instance were pre-provisioned:
- Cluster: `cymbal-cluster`
- Instance: `cymbal-instance`
- Database: `postgres`
- User: `postgres`

Wait until both show **Status: Ready**.

---

## 1.2 Enable vector extension + permissions
In **AlloyDB Studio**, run:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
````

Then grant permission to execute the embedding function:

```sql
GRANT EXECUTE ON FUNCTION embedding TO postgres;
```

### Why this matters (in plain English)

* The **vector extension** lets Postgres store “meaning vectors” (embeddings) in a special column type.
* The **embedding() function** is a helper that calls a model (via Vertex AI integration) to turn text into vectors.

---

## 1.3 Allow AlloyDB to call Vertex AI (IAM)

Grant the AlloyDB service account the role:

* `Vertex AI User`

This enables embedding generation using a Vertex AI text embedding model.

---

## 1.4 Create schema + load sample data

Create table:

```sql
CREATE TABLE customer_records_data (
    id VARCHAR(25),
    type VARCHAR(25),
    number VARCHAR(20),
    country VARCHAR(2),
    date VARCHAR(20),
    abstract VARCHAR(300000),
    title VARCHAR(100000),
    kind VARCHAR(6),
    num_claims BIGINT,
    filename VARCHAR(100),
    withdrawn BIGINT,
    abstract_embeddings vector(768)
);
```

Load records (policies + articles) into `customer_records_data`.

### What’s happening here

* `abstract` is the text we want the AI to “understand”.
* `abstract_embeddings` is where we store the numeric embedding vector (768 dimensions here).

---

## 1.5 Generate embeddings

Test:

```sql
SELECT embedding('text-embedding-005', 'AlloyDB is a managed, cloud-hosted SQL database service.');
```

Generate for all rows:

```sql
UPDATE customer_records_data
SET abstract_embeddings = embedding('text-embedding-005', abstract);
```

---

## 1.6 Run a vector similarity search

Example query:

```sql
SELECT id, title, abstract
FROM customer_records_data
ORDER BY abstract_embeddings <=> embedding('text-embedding-005', 'what should I do about water damage in my home?')::vector
LIMIT 10;
```

### Why this is cool

This doesn’t rely on keyword matches.
It finds results that are **semantically similar** (meaning-based).

---

## 1.7 Speed it up with an index (ScaNN / ivfflat)

Create an index:

```sql
CREATE INDEX ON customer_records_data
USING ivfflat (abstract_embeddings vector_l2_ops)
WITH (lists = 100);
```

### In plain English

An **index** is like a table of contents for fast lookup.
For vector search, it helps you find “nearest neighbors” quickly even in large datasets.

---

# Chapter 2 — Secure API Layer (MCP Toolbox on Cloud Run)

Goal: expose **safe, approved database actions** as “tools” behind a private API.

## 2.1 Allow connectivity (public IP for setup, then keep traffic private)

In the lab, you temporarily enabled AlloyDB public IP and allowed your Cloud Shell IP range.

> In real setups, you’d typically prefer private IP + private connectivity from the start.

---

## 2.2 Create a Service Account for the toolbox

Create:

```bash
gcloud iam service-accounts create toolbox-identity \
  --display-name="MCP Toolbox Service"
```

Grant least-privilege roles:

* `roles/secretmanager.secretAccessor`
* `roles/alloydb.client`
* `roles/serviceusage.serviceUsageConsumer`

Also grant yourself:

* `roles/iam.serviceAccountUser` on that service account (so you can deploy as it)

### In plain English

A **service account** is a “program identity.”
Instead of you logging in, Cloud Run uses that identity to access resources—only with the permissions you grant.

---

## 2.3 Store DB password in Secret Manager

```bash
echo 'changeme' | gcloud secrets create alloydb-password --data-file=-
export DB_PASSWORD=$(gcloud secrets versions access latest --secret="alloydb-password")
```

---

## 2.4 Define tools in `tools.yaml`

`tools.yaml` is the **tool blueprint**: it defines

* how to connect to the database
* which SQL statements are allowed
* what parameters the agent can pass

Example tools included:

* `find_similar_customer_records` (vector similarity search)
* `get_record_by_id` (exact lookup by ID)

> This is the “guardrail”: the agent can only do what’s in this file.

---

## 2.5 Run MCP Toolbox locally (optional quick test)

```bash
./toolbox --tools-file "tools.yaml" --port=8080
```

---

## 2.6 Deploy MCP Toolbox to Cloud Run (private)

Create a secret from `tools.yaml`:

```bash
gcloud secrets create tools --data-file=tools.yaml
# or, if it already exists:
gcloud secrets versions add tools --data-file=tools.yaml
```

Create VPC connector:

```bash
gcloud compute networks vpc-access connectors create alloydb-connector \
  --region=${REGION} \
  --network=peering-network \
  --range=10.8.0.0/28
```

Deploy:

```bash
gcloud run deploy toolbox \
  --image=${TARGET_IMAGE} \
  --vpc-connector=alloydb-connector \
  --region=${REGION} \
  --service-account=toolbox-identity \
  --no-allow-unauthenticated \
  --set-secrets="/app/tools.yaml=tools:latest" \
  --args="--tools-file=/app/tools.yaml","--address=0.0.0.0","--port=8080" \
  --ingress=internal \
  --min-instances=1
```

Save the internal service URL:

```bash
export SECURE_API_URL="https://<your-cloud-run-service-url>"
```

### In plain English

* **Cloud Run** runs your API without you managing servers.
* **Ingress internal** means the service is not publicly accessible.
* The toolbox reads **tools.yaml from a secret**, not from plain text files.

---

# Chapter 3 — Agent Layer (ADK + Gemini + tool calling)

Goal: build an agent that can:

1. understand a natural-language question
2. choose an appropriate tool
3. call the secure API
4. summarize the returned database results

## 3.1 Create ADK environment

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install google-adk toolbox-core
```

---

## 3.2 Create the ADK agent skeleton

```bash
adk create multi_tool_agent
```

Chosen options (lab):

* Model: `gemini-2.5-flash`
* Backend: Vertex AI

---

## 3.3 Connect the agent to the tool gateway (Cloud Run)

Copy `tools.yaml` into agent directory so ADK can discover the toolset:

```bash
cp ../tools.yaml .
```

Example agent definition (simplified):

```py
from google.adk.agents import Agent
from toolbox_core import ToolboxSyncClient

toolbox = ToolboxSyncClient(SECURE_API_URL)
tools = toolbox.load_toolset("customer_data_tools")

root_agent = Agent(
    name="claims_assistant",
    model="gemini-2.5-flash",
    description="Helps insurance adjusters find relevant policies/articles safely.",
    instruction=(
        "You are an insurance claims assistant. "
        "Use tools to (1) run semantic search over policies/articles "
        "and (2) fetch a record by its ID."
    ),
    tools=tools,
)
```

> The agent **does not need DB credentials**. It only needs the secure API URL and permission to call it.

---

## 3.4 Run the ADK Dev UI and test

```bash
adk web
```

Example prompts to try:

* “Find articles about roof damage from storms.”
* “What’s the procedure for water damage mitigation?”
* “Retrieve policy POL-10326103.”

---

# Glossary

### Infrastructure & environment

* **Vertex AI**: Google Cloud’s AI platform where Gemini models live and are managed. Think: the agent’s “brain provider.”
* **Cloud Run**: A serverless way to deploy code. You provide a container, Google runs it and scales it.
* **VPC (Virtual Private Cloud)**: Your private network boundary in the cloud. It lets services talk internally without going over the public internet.
* **Service Account**: A non-human identity for programs (Cloud Run, agents, pipelines). You grant it specific permissions.

### Data & search

* **Text Embedding**: Turning text into a numeric vector so a computer can compare meaning, not just keywords.
* **Vector Search**: Searching by semantic similarity using embeddings (e.g., “roof damage” finds “storm tarping”).
* **Cosine Distance**: A way to measure how similar two vectors are by comparing their direction (smaller distance / larger similarity = more related).
* **Index (ScaNN / ivfflat)**: A performance structure that speeds up “nearest neighbor” search across many vectors.

### Agent + tooling

* **Agentic AI**: An AI that doesn’t only answer— it can decide to use tools and take steps toward a goal.
* **ADK (Agent Development Kit)**: Google’s Python toolkit for defining agents (persona + tools + behavior).
* **MCP & Toolbox**: A standardized, safer bridge between models and external systems (like databases). Toolbox exposes approved “tools” over an API.
* **tools.yaml**: The tool blueprint—defines allowed database connections + SQL queries + parameters.
* **SECURE_API_URL**: The Cloud Run endpoint the agent calls to use tools safely.

### A few extra terms you’ll run into

* **AlloyDB**: Google’s managed Postgres-compatible database optimized for performance (and here, vector search).
* **pgvector / vector extension**: The Postgres extension that adds the `vector` type and vector operators.
* **Tool calling**: The model decides to call a function/tool (instead of guessing) to fetch real data.

---

# Security notes (the “why this pattern exists” part)

* Agents should **not** have direct DB access: it’s too easy to over-query, leak data, or do unintended actions.
* The **API tool gateway** enforces:

  * which queries are allowed (only what’s in `tools.yaml`)
  * authentication (no anonymous calls)
  * network isolation (internal ingress + VPC routing)
* You can add logging, rate limits, audit trails, and approvals at the API layer.

---

# Credits / Inspiration

This repo is based on a Google Cloud Skills Boost lab pattern:

* AlloyDB + embeddings + vector search
* MCP Toolbox for Databases on Cloud Run
* ADK agent using Gemini via Vertex AI

---

## License

For educational/demo purposes. Adapt freely for your own projects.
