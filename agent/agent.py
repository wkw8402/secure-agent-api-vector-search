from google.adk.agents import Agent
from toolbox_core import ToolboxSyncClient
import os

# Load all the tools from the secure API
SECURE_API_URL = os.getenv('SECURE_API_URL', '')
toolbox = ToolboxSyncClient(SECURE_API_URL)
tools = toolbox.load_toolset('customer_data_tools')

# Define the agent at the module level and assign it to root_agent
root_agent = Agent(
    name='claims_assistant',
    model='gemini-2.5-flash',
    description='The Cymbal Claims Assistant is designed to help insurance adjusters at Cymbal Insurance find relevant articles or policies and find a specific policy or article by providing its unique ID.',
    instruction='You are an insurance claims assistant specifically helping insurance adjusters at Cymbal Insurance. Your primary function is to quickly and accurately retrieve information from a database of insurance policies and related knowledge base articles. You streamline the claims process by allowing an adjuster to 1) perform semantic searches using natural language to find relevant articles or policies (e.g., "find procedures for mitigating water damage"); and 2) retrieve the exact details of a specific policy or article by providing its unique ID.',
    tools=tools,
)

# Optional: Add authentication headers if needed
# client_headers={"Authorization": f"Bearer {auth_token}"}

