# install-kubewarden-action

This is a Github action that creates a K3D cluster and install the Kubewarden
stack on it. The action allow the user define the container image used in the
Kubewarden controller and the Policy Server.

The configurations allowed are:

| Configuration | Description | Required | Default value |
| ------------- | ----------- | -------- | ------------- |
| controller-image-repository | Define the controller container image repository | false | "" |
| controller-image-tag | Define the controller container image tag | false | "" |
| controller-container-image-artifact | Load the image used in the deployment from local artifact | false | "" |
| policy-server-repository | Define the policy server container image tag | false | "ghcr.io/kubewarden/policy-server" |
| policy-server-tag | Define the policy server container image tag | false | "v0.2.5" |
| policy-server-container-image-artifact | Load the policy server image used in the deployment from local artifact | false | "" |
| cluster-name | K3d cluster name | false | "kubewarden-test-cluster" |

If the user define the `controller-container-image-artifact` and `policy-server-container-image-artifact` the
action will load the Docker image present in these tarballs into the K3D cluster. Thus, the image
can be used in the Kubewarden installation defining the right image repository and tag.
