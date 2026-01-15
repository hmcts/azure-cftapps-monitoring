import sys
import uuid
from azure.cosmos import CosmosClient, PartitionKey
from azure.identity import DefaultAzureCredential
import argparse

# Get the command-line arguments
cosmos_account = "pipeline-metrics"
cosmos_db = "platform-metrics"
cosmos_container = "failed-deployments"

parser = argparse.ArgumentParser(description="Script to send JSON data to Cosmos DB.")

parser.add_argument('--clusterName', type=str, required=True, help='The cluster name')
parser.add_argument('--namespace', type=str, required=True, help='The namespace')
parser.add_argument('--deploymentName', type=str, required=True, help='The deprecated chart name')
parser.add_argument('--readyReplicas', type=str, required=True, help='The current number of replica pods in read state')
parser.add_argument('--desiredReplicas', type=str, required=True, help='The desired number of replica pods')
parser.add_argument('--slackChannel', type=str, required=True, help='The Slack channel to notify')

# Parse the arguments
args = parser.parse_args()

cluster_name = args.clusterName
namespace = args.namespace
deployment_name = args.deploymentName
ready_replicas = args.readyReplicas
desired_replicas = args.desiredReplicas
slack_channel = args.slackChannel

endpoint = f"https://{cosmos_account}.documents.azure.com:443/"
credential = DefaultAzureCredential()
client = CosmosClient(endpoint, credential=credential)
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

print(document, "created successfully in Cosmos")
