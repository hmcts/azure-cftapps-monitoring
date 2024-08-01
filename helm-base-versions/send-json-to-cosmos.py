import os
import sys
import uuid
from azure.cosmos import CosmosClient, PartitionKey
from azure.identity import DefaultAzureCredential
import argparse

# Environment variables for Cosmos DB configuration
cosmos_account = os.environ.get("COSMOS_ACCOUNT", "pipeline-metrics")
cosmos_db = os.environ.get("COSMOS_DB", "platform-metrics")
cosmos_container = os.environ.get("COSMOS_CONTAINER", "app-helm-chart-metrics")

# Command-line argument parser
parser = argparse.ArgumentParser(description="Script to send JSON data to Cosmos DB.")

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

# Cosmos DB endpoint and client setup
endpoint = f"https://{cosmos_account}.documents.azure.com:443/"
credential = DefaultAzureCredential()
client = CosmosClient(endpoint, credential=credential)
database = client.get_database_client(cosmos_db)
container = database.get_container_client(cosmos_container)


# Create document
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

# Insert document into Cosmos DB
container.create_item(body=document)

print(document, "created successfully in Cosmos")