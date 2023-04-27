import sys
import uuid
from azure.cosmos import CosmosClient, PartitionKey

# Get the command-line arguments
cosmos_account = "pipeline-metrics"
cosmos_db = "platform-metrics"
cosmos_container = "app-helm-chart-metrics"
cosmos_key = sys.argv[1]
chart_name = sys.argv[2]
namespace = sys.argv[3]
cluster_name = sys.argv[4]
deprecated_chart_name = sys.argv[5]
current_version = sys.argv[6]
is_deprecated = sys.argv[7]
is_error = sys.argv[8]

# Define the Cosmos DB endpoint and initialize the Cosmos DB client and container
endpoint = f"https://{cosmos_account}.documents.azure.com:443/"
client = CosmosClient(endpoint, cosmos_key)
database = client.get_database_client(cosmos_db)
container = database.get_container_client(cosmos_container)

doc_id = str(uuid.uuid4())
document = {
    "id": doc_id,
    "chartName": chart_name,
    "namespace": namespace,
    "clusterName": cluster_name,
    "baseChart": deprecated_chart_name,
    "baseChartVersion": current_version,
    "isDeprecated": is_deprecated,
    "isError": is_error,
}
container.create_item(body=document)

print(document + " created successfully in Cosmos")
