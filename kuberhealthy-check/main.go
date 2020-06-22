// Package podStatus implements a pod health checker for Kuberhealthy.  Pods are checked
// to ensure they are not restarting too much and are in a healthy lifecycle phase.
package main

import (
	"os"
	"path/filepath"

	checkclient "github.com/Comcast/kuberhealthy/v2/pkg/checks/external/checkclient"
	"github.com/Comcast/kuberhealthy/v2/pkg/kubeClient"
	"k8s.io/apimachinery/pkg/api/errors"

	// required for oidc kubectl testing
	log "github.com/sirupsen/logrus"
	v1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

var KubeConfigFile = filepath.Join(os.Getenv("HOME"), ".kube", "config")
var targetNamespace string
var deploymentName string
var serviceName string
var podLabel string

func init() {
	targetNamespace = os.Getenv("TARGET_NAMESPACE")
	deploymentName = os.Getenv("DEPLOYMENT_NAME")
	serviceName = os.Getenv("SERVICE_NAME")
	podLabel = os.Getenv("POD_LABEL")
	checkclient.Debug = os.Getenv("CHECK_CLIENT_DEBUG")
	log.Debugln("deploymentName : ", deploymentName)
	log.Debugln("serviceName : ", serviceName)
	log.Debugln("targetNamespace : ", targetNamespace)
	log.Debugln("podLabel : ", podLabel)
}

func main() {

	client, err := kubeClient.Create(KubeConfigFile)
	if err != nil {
		log.Fatalln("Unable to create kubernetes client", err)
	}
	if len(deploymentName) > 0 {
		log.Infoln("performing deployment check", deploymentName, targetNamespace)
		deployment, failures := getDeployment(client, deploymentName, targetNamespace)
		if deployment.Status.ReadyReplicas >= 1 {
			log.Infoln("check successful, at least 1 replica found.")
			reportSuccess()
			return
		}
		reportFailure(failures)
	} else if len(serviceName) > 0 {
		log.Infoln("performing load balancer ip check", serviceName, targetNamespace)
		service, failures := getService(client, serviceName, targetNamespace)
		if len(service.Status.LoadBalancer.Ingress[0].IP) > 0 {
			log.Infoln("check successful, load balancer ip is set")
			reportSuccess()
			return
		}
		reportFailure(failures)
	} else if len(podLabel) > 0 {
		log.Infoln("performing pod running check", podLabel, targetNamespace)
		pods, failures := getPodsByLabel(client, podLabel, targetNamespace)
		for _, pod := range pods.Items {
			if pod.Status.Phase == corev1.PodRunning {
				reportSuccess()
				return
			}
			failures = append(failures, "Pod not running", pod.Name)
			return
		}
		reportFailure(failures)
	}

}

func getDeployment(clientset *kubernetes.Clientset, deploymentName string, namespace string) (deployment *v1.Deployment, failures []string) {
	deployment, err := clientset.AppsV1().Deployments(namespace).Get(deploymentName, metav1.GetOptions{})
	if errors.IsNotFound(err) {
		failures = append(failures, "deployment not found")
	} else if statusError, isStatus := err.(*errors.StatusError); isStatus {
		failures = append(failures, "Error getting deployment", statusError.ErrStatus.Message)
	} else if err != nil {
		failures = append(failures, "Error getting deployment", err.Error())
	}
	return deployment, failures
}

func getService(clientset *kubernetes.Clientset, serviceName string, namespace string) (service *corev1.Service, failures []string) {

	service, err := clientset.CoreV1().Services(namespace).Get(serviceName, metav1.GetOptions{})
	if errors.IsNotFound(err) {
		failures = append(failures, "service not found")
	} else if statusError, isStatus := err.(*errors.StatusError); isStatus {
		failures = append(failures, "Error getting service", statusError.ErrStatus.Message)
	} else if err != nil {
		failures = append(failures, "Error getting service", err.Error())
	}
	return service, failures
}

func getPodsByLabel(clientset *kubernetes.Clientset, label string, namespace string) (pods *corev1.PodList, failures []string) {
	pods, err := clientset.CoreV1().Pods(namespace).List(metav1.ListOptions{LabelSelector: label})
	if errors.IsNotFound(err) {
		failures = append(failures, "pods not found")
	} else if statusError, isStatus := err.(*errors.StatusError); isStatus {
		failures = append(failures, "Error getting pods", statusError.ErrStatus.Message)
	} else if err != nil {
		failures = append(failures, "Error getting pods", err.Error())
	}
	return pods, failures
}

func reportSuccess() {
	err := checkclient.ReportSuccess()
	if err != nil {
		log.Println("Error reporting success to Kuberhealthy servers", err)
		os.Exit(1)
	}
}

func reportFailure(failures []string) {
	log.Println("Reporting failures", failures)
	err := checkclient.ReportFailure(failures)
	if err != nil {
		log.Println("Error reporting failures to Kuber healthy servers", err)
		os.Exit(1)
	}
}
