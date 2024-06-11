# send-slack-alerts.py
import datetime
import sys
import requests
import logging
from azure.cosmos import CosmosClient

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Get the command-line arguments
cosmos_account = "pipeline-metrics"
cosmos_db = "platform-metrics"
cosmos_container = "failed-deployments"
cosmos_key = sys.argv[1]
slack_webhook = sys.argv[2]

# Define the Cosmos DB endpoint and initialize the Cosmos DB client and container
endpoint = f"https://{cosmos_account}.documents.azure.com:443/"
client = CosmosClient(endpoint, cosmos_key)
database = client.get_database_client(cosmos_db)
container = database.get_container_client(cosmos_container)

midnight = datetime.datetime.now(datetime.timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)

# Query Cosmos DB for failed deployments since midnight
items = list(container.query_items(
    query="SELECT c.clusterName, c.namespace, c.deploymentName, c.readyReplicas, c.desiredReplicas, c.slackChannel "
          "FROM c WHERE c.timestamp > @timestamp",
    parameters=[
        {"name": "@timestamp", "value": midnight.isoformat()}
    ],
    enable_cross_partition_query=True
))

# Create a map of failed deployments by namespace and Slack channel
failed_deployments = {}
for item in items:
    channel = item['slackChannel']
    namespace = item['namespace']
    if channel not in failed_deployments:
        failed_deployments[channel] = {}
    if namespace not in failed_deployments[channel]:
        failed_deployments[channel][namespace] = []
    failed_deployments[channel][namespace].append(item)

# Send notifications to Slack
for channel, namespaces in failed_deployments.items():
    for namespace, deployments in namespaces.items():
        slack_message = f":warning: *Failed Deployments Detected in Namespace {namespace}*\n"
        for deployment in deployments:
            slack_message += f"> Cluster: {deployment['clusterName']}, Deployment: {deployment['deploymentName']}, Ready Replicas: {deployment['readyReplicas']}, Desired Replicas: {deployment['desiredReplicas']}\n"
        payload = {
            "channel": channel,
            "username": "Deployment Monitor",
            "text": slack_message,
            "icon_emoji": ":flux:",
        }
        
        logging.info(f"Sending Slack message to channel {channel} for namespace {namespace}")
        logging.debug(f"Slack message payload: {payload}")
        
        response = requests.post(slack_webhook, json=payload)
        
        if response.status_code == 200:
            logging.info(f"Slack message sent successfully to channel {channel} for namespace {namespace}")
        else:
            logging.error(f"Failed to send Slack message to channel {channel} for namespace {namespace}. Response: {response.text}")

logging.info("Script execution completed.")
