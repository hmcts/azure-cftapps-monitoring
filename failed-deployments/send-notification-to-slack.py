import datetime
import sys
import requests
from azure.cosmos import CosmosClient, PartitionKey

# Get the command-line arguments
cosmos_account = "pipeline-metrics"
cosmos_db = "platform-metrics"
cosmos_container = "app-helm-chart-metrics"
cosmos_key = sys.argv[1]
slack_webhook = sys.argv[2]
namespace = sys.argv[3]
slack_channel = sys.argv[4]

# Define the Cosmos DB endpoint and initialize the Cosmos DB client and container
endpoint = f"https://{cosmos_account}.documents.azure.com:443/"
client = CosmosClient(endpoint, cosmos_key)
database = client.get_database_client(cosmos_db)
container = database.get_container_client(cosmos_container)

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


