import sys
import uuid
from azure.cosmos import CosmosClient, PartitionKey
from azure.identity import DefaultAzureCredential
import argparse

# Get the command-line arguments
cosmos_account = "pipeline-metrics"
cosmos_db = "platform-metrics"
cosmos_container = "app-helm-chart-metrics"

parser = argparse.ArgumentParser(description="Process some integers.")

parser.add_argument('--chart_name', type=str, required=True, help='The chart name')
parser.add_argument('--namespace', type=str, required=True, help='The namespace')
parser.add_argument('--cluster_name', type=str, required=True, help='The cluster name')
parser.add_argument('--deprecated_chart_name', type=str, required=True, help='The deprecated chart name')
parser.add_argument('--current_version', type=str, required=True, help='The current version of the chart')
parser.add_argument('--is_deprecated', type=str, required=True, help='Deprecation status')
parser.add_argument('--flag', type=str, required=True, help='A boolean flag')
parser.add_argument('--is_error', action='store_true', help='A boolean flag indicating an error')

# Parse the arguments
args = parser.parse_args()

chart_name = args.chart_name
namespace = args.namespace
cluster_name = args.cluster_name
deprecated_chart_name = args.deprecated_chart_name
current_version = args.current_version
is_deprecated = args.is_deprecated
flag = args.flag
is_error = args.is_error

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

print(document ," created successfully in Cosmos")
