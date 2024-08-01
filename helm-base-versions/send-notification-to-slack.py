import datetime
import os
import sys
import requests
from azure.cosmos import CosmosClient, PartitionKey
from azure.identity import DefaultAzureCredential
import argparse

# Get the command-line arguments
cosmos_account = os.environ.get("COSMOS_ACCOUNT", "pipeline-metrics")
cosmos_db = os.environ.get("COSMOS_DB", "platform-metrics")
cosmos_container = os.environ.get("COSMOS_CONTAINER", "app-helm-chart-metrics")

parser = argparse.ArgumentParser(description="Script to send notifications to Slack.")

parser.add_argument('--slack_webhook', type=str, required=True, help='The URL of the Slack webhook to send notifications to.')
parser.add_argument('--namespace', type=str, required=True, help='The namespace associated with the notification.')
parser.add_argument('--slack_channel', type=str, required=True, help='The Slack channel to post the notification to.')

# Parse the arguments
args = parser.parse_args()

slack_webhook = args.slack_webhook
namespace = args.namespace
slack_channel = args.slack_channel

# Define the Cosmos DB endpoint and initialize the Cosmos DB client and container
endpoint = f"https://{cosmos_account}.documents.azure.com:443/"
credential = DefaultAzureCredential()
client = CosmosClient(endpoint, credential=credential)
database = client.get_database_client(cosmos_db)
db_container = database.get_container_client(cosmos_container)

midnight = datetime.datetime.now(datetime.timezone.utc).replace(hour = 0, minute = 0, second = 0, microsecond = 0)

# enable_cross_partition_query should be set to True as the container is partitioned
items = list(container.query_items(
    query="SELECT distinct c.clusterName, c.chartName, c.baseChart, c.baseChartVersion "
          "FROM c where c.isDeprecated='true' and c._ts >@timestamp and c.namespace=@ns",
    parameters=[
        { "name":"@ns", "value": namespace },
        { "name":"@timestamp", "value": midnight.timestamp() }
    ],
    enable_cross_partition_query=True
))

chartsMap = {}
for item in items:
    t = chartsMap.setdefault(item['chartName'], [])
    t.append(item)

bullet_delimiter = "\n> :red: "
for chartName in chartsMap:
    baseChart = chartsMap[chartName][0]["baseChart"]
    baseChartVersion = chartsMap[chartName][0]["baseChartVersion"]
    if baseChart == "":
        slackMessage = f">*{chartName}* chart has invalid configuration on the below clusters," \
                       f" please fix the configuration:\n>"
    else:
        slackMessage = f">*{chartName}* chart is using a deprecated chart *{baseChart}* version *{baseChartVersion}*" \
                       f" on the below clusters, please upgrade to the <https://github.com/hmcts/chart-{baseChart}/releases|latest release>:\n>"
    clusters = []
    for deprecation in chartsMap[chartName]:
        clusters.append(deprecation["clusterName"])
    slackMessage += bullet_delimiter
    slackMessage += bullet_delimiter.join(clusters)
    print(slackMessage)
    payload = {
        "channel": slack_channel,
        "username": "Helm Deprecation",
        "text": slackMessage,
        "icon_emoji": ":flux:",
    }
    requests.post(slack_webhook, json=payload)


