import sys
import uuid
from azure.cosmos import CosmosClient, PartitionKey
from azure.identity import DefaultAzureCredential
import argparse

# Get the command-line arguments
cosmos_account = "pipeline-metrics"
cosmos_db = "platform-metrics"
cosmos_container = "app-helm-chart-metrics"

parser = argparse.ArgumentParser(description="Script to send JSON data to Cosmos DB.")

parser.add_argument('--chartName', type=str, required=True, help='The chart name')
parser.add_argument('--namespace', type=str, required=True, help='The namespace')
parser.add_argument('--clusterName', type=str, required=True, help='The cluster name')
parser.add_argument('--deprecatedChartName', type=str, required=True, help='The deprecated chart name')
parser.add_argument('--currentVersion', type=str, required=True, help='The current version of the chart')
parser.add_argument('--isDeprecated', type=str, required=True, help='Deprecation status')
parser.add_argument('--flag', type=str, required=True, help='A boolean flag')
parser.add_argument('--isError', action='store_true', help='A boolean flag indicating an error')

# Parse the arguments
args = parser.parse_args()

chart_name = args.chartName
namespace = args.namespace
cluster_name = args.clusterName
deprecated_chart_name = args.deprecatedChartName
current_version = args.currentVersion
is_deprecated = args.isDeprecated
flag = args.flag
is_error = args.isError

endpoint = f"https://{cosmos_account}.documents.azure.com:443/"
credential = DefaultAzureCredential()
client = CosmosClient(endpoint, credential=credential)
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

print(document, "created successfully in Cosmos")
