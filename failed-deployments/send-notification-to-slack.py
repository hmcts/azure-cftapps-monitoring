import sys
import uuid
import requests
from azure.cosmos import CosmosClient

# Get the command-line arguments
cosmos_account = "pipeline-metrics"
cosmos_db = "platform-metrics"
cosmos_container = "failed-deployments"
cosmos_key = sys.argv[1]
cluster_name = sys.argv[2]
namespace = sys.argv[3]
deployment_name = sys.argv[4]
ready_replicas = sys.argv[5]
desired_replicas = sys.argv[6]
slack_channel = sys.argv[7]
slack_webhook = sys.argv[8]

# Define the Cosmos DB endpoint and initialize the Cosmos DB client and container
endpoint = f"https://{cosmos_account}.documents.azure.com:443/"
client = CosmosClient(endpoint, cosmos_key)
database = client.get_database_client(cosmos_db)
container = database.get_container_client(cosmos_container)

# Create a document to store in Cosmos DB
doc_id = str(uuid.uuid4())
document = {
    "id": doc_id,
    "deploymentName": deployment_name,
    "namespace": namespace,
    "clusterName": cluster_name,
    "readyReplicas": ready_replicas,
    "desiredReplicas": desired_replicas,
    "isFailed": True,
    "slackChannel": slack_channel
}
container.create_item(body=document)

print(f"Document {document} created successfully in Cosmos DB")

# Send a message to Slack
slack_message = (
    f"> :red_circle: Deployment `{deployment_name}` in namespace `{namespace}` on cluster `{cluster_name}` "
    f"has failed. Ready replicas: `{ready_replicas}`, Desired replicas: `{desired_replicas}`."
)
payload = {
    "channel": slack_channel,
    "username": "Deployment Monitor",
    "text": slack_message,
    "icon_emoji": ":flux:",
}
response = requests.post(slack_webhook, json=payload)

if response.status_code == 200:
    print("Message posted successfully to Slack")
else:
    print(f"Failed to post message to Slack: {response.status_code}, {response.text}")
