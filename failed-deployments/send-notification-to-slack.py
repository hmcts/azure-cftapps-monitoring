import datetime
import sys
import requests
import logging
from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential

# Configure logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

# Get the command-line arguments
cosmos_account = "pipeline-metrics"
cosmos_db = "platform-metrics"
cosmos_container = "failed-deployments"
slack_webhook = sys.argv[2]

# Define the Cosmos DB endpoint and initialize the Cosmos DB client and container
endpoint = f"https://{cosmos_account}.documents.azure.com:443/"
credential = DefaultAzureCredential()
client = CosmosClient(endpoint, credential=credential)
database = client.get_database_client(cosmos_db)
container = database.get_container_client(cosmos_container)

# Calculate midnight time in epoch seconds
midnight = datetime.datetime.now(datetime.timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
midnight_epoch = int(midnight.timestamp())
logging.debug(f"Querying for items with _ts greater than {midnight_epoch}")

# Query Cosmos DB for failed deployments since midnight
items = list(container.query_items(
    query="SELECT c.clusterName, c.namespace, c.deploymentName, c.readyReplicas, c.desiredReplicas, c.slackChannel "
          "FROM c WHERE c._ts > @timestamp",
    parameters=[
        {"name": "@timestamp", "value": midnight_epoch}
    ],
    enable_cross_partition_query=True
))

logging.info(f"Query returned {len(items)} items.")
for item in items:
    logging.debug(f"Item: {item}")

# Create a map of failed deployments by namespace and Slack channel
failed_deployments = {}
for item in items:
    logging.debug(f"Processing item: {item}")
    channel = item['slackChannel']
    namespace = item['namespace']
    if channel not in failed_deployments:
        failed_deployments[channel] = {}
    if namespace not in failed_deployments[channel]:
        failed_deployments[channel][namespace] = []
    failed_deployments[channel][namespace].append(item)

logging.debug(f"Failed deployments grouped by channel and namespace: {failed_deployments}")

# Send notifications to Slack
for channel, namespaces in failed_deployments.items():
    for namespace, deployments in namespaces.items():
        slack_message = f":warning: *Failed Deployments Detected in Namespace {namespace}*\n"
        for deployment in deployments:
            slack_message += f"> :red: Deployment: *{deployment['deploymentName']}* has failed on *{deployment['clusterName']}*\n"
        payload = {
            "channel": channel,
            "username": "Failed Deployments",
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
