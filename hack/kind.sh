# Based on https://github.com/openshift/cluster-network-operator/blob/master/hack/ovn-kind-cno.sh

K8S_VERSION=${K8S_VERSION:-v1.21.1}
KIND_CONFIG=$(mktemp /tmp/kind-config.XXXXXX}
# TODO



# Build images
docker pull registry.ci.openshift.org/ocp/builder:rhel-8-golang-1.16-openshift-4.9
docker pull registry.ci.openshift.org/ocp/4.9:base

make images

# TODO Figure out later how to make this a template
docker tag registry.ci.openshift.org/ocp/4.3:cluster-kube-apiserver-operator docker.io/openshift/origin-cluster-kube-apiserver-operator:v4.0 

kind load docker-image docker.io/openshift/origin-cluster-kube-apiserver-operator:v4.0

# Create cluster

# create the config file
cat <<EOF > ${KIND_CONFIG}
# config for 1 control plane node and 2 workers (necessary for conformance)
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
kubeadmConfigPatches:
- |
  kind: ClusterConfiguration
  controllerManager:
    extraArgs:
      cluster-signing-cert-file: /etc/kubernetes/pki/ca.crt
      cluster-signing-key-file: /etc/kubernetes/pki/ca.key
EOF


# Create KIND cluster
kind create cluster --name openshift --image kindest/node:${K8S_VERSION} --config=${KIND_CONFIG} -v 4


# Install CRDs

for i in $(find vendor/github.com/openshift/api -name 000*yaml); do
  oc apply -f $i
done


# Create cluster config
NUM_MASTER_NODES=1
echo "Creating \"cluster-config-v1\" configMap with $NUM_MASTER_NODES master nodes"
cat <<EOF | oc create -f - 
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-config-v1
  namespace: kube-system
data:
  install-config: |
    apiVersion: v1
    controlPlane:
      replicas: ${NUM_MASTER_NODES}
EOF


# Install operator config and operator

kubectl apply -f bindata/assets/config/defaultconfig.yaml

for i in $(find manifests/ -name 0000_20*yaml); do
  oc apply -f $i
done

# bootstrap

# normal

for f in $(ls $_TEMPLATES| grep 0000| grep -v credentials); do
  kubectl create -f ${KAPI_TEMPLATES}/$f
done




