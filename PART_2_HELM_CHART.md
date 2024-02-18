## Helm chart fixes and improvements

The [original](https://github.com/SwissBorg/sre-tech-challenge-senior) helm chart contained
some issues, and it was not generating manifests properly using Helm.

The main issues were:
* Incorrect image defined `image: nginx:latets` instead of `image: nginx:latest`
* Incorrect cpu resources.requests.cpu value: `+500m` instead of `500m`
* Incorrect `piVersion: v1` instead of `apiVersion: v1`
* The chart assumes that there is a storageclasses.storage.k8s.io named `manual` available in the cluster
* The readiness probe was pointing to /ping, however there is no /ping path resource from the default nginx image
* The secret's key my-secret should be base64 encoded
* The servicePort property was pointing to the container's targetPort 8080, but nginx exposes 80. servicePort property renamed to targetPort instead to prevent confusion.

A few improvements were applied to the original chart, the improved version can be found [here](https://github.com/lorenzo85/sre-challenge/tree/master/charts/sre-tech-challenge-senior).

The major changes were about giving the possibility to override only the nginx image **tag** instead of the
entire image and rendering "optionally" the resources.limits.cpu as it seems to be an "optional" argument.

Also the chart has been improved using helper functions to define resources 
names shared/referenced across different resources definitions.

