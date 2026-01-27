# GKE GitOps Infrastructure

This repository contains the Kubernetes manifests for the application, managed by Kustomize and deployed via ArgoCD.

## KEDA Installation

If KEDA fails to install correctly, it may be due to a race condition or finalizers preventing the `keda` namespace from being cleaned up. Follow these steps for a robust installation.

### Step 1: Force-Delete the KEDA Namespace

If the `keda` namespace is stuck in a `Terminating` state, you must patch its finalizers to null to force its deletion.

```bash
kubectl patch namespace keda -p '{"metadata":{"finalizers":null}}'
```

### Step 2: Clean Up Leaked Cluster-Scoped Resources

After the namespace is gone, manually delete any remaining cluster-scoped resources left behind from the failed installation.

```bash
# Delete ClusterRoles and ClusterRoleBindings
kubectl delete clusterrolebinding keda-hpa-controller-external-metrics
kubectl delete clusterrole keda-external-metrics-reader
kubectl delete clusterrole keda-hpa-controller-external-metrics 

# Delete APIService for metrics
kubectl delete apiservice v1beta1.external.metrics.k8s.io

# Delete ValidatingWebhookConfiguration
kubectl delete validatingwebhookconfiguration keda-admission
```

### Step 3: Perform a Clean Installation

With all remnants of the old installation removed, perform a fresh, server-side apply of the KEDA manifests. Using `--server-side` helps avoid issues with oversized annotations.

```bash
kubectl apply --server-side -f https://github.com/kedacore/keda/releases/download/v2.14.0/keda-2.14.0.yaml
```

### Step 4: Verify the Installation

Wait for the KEDA pods to be created and enter a `Running` state.

```bash
kubectl get pods -n keda
```

You should see the `keda-operator`, `keda-metrics-apiserver`, and `keda-admission` pods running. Once they are, you can also verify that the `scaledjobs.keda.sh` CRD is established.

```bash
kubectl get crd scaledjobs.keda.sh
```

This completes the robust KEDA setup.