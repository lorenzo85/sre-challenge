# Production readiness

To make the deployed application stack production ready, the following steps are needed:

* Terraform configuration, ArgoCD applications and the other scripts need to be adjusted to have at least 3 sets of configurations variations pointing to development, staging and production environments. This also includes creating 3 distinct branches on Git dedicated to each environment.
* Set up CI/CD configuration (e.g GitHub workflows) to automatically build applications code, build new [Helm chart](https://github.com/lorenzo85/sre-challenge/blob/4bc072336a18b50eec24491187191819d0814964/.github/workflows/release.yml) version, update ArgoCD applications targetRevisions with the new release and push it to the cluster.
* Configure critical deployments to have a minimum number of replicas set to 2 and [topology spread constraint](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/) based on the Availability Zone of the nodes (topology key: topology.kubernetes.io/zone can be used).
* Configure Kubernetes Horizontal Pod Autoscaling to scale based on CPU or Memory, depending on the workloads (e.g CPU or Memory intensive) 
* Configure Grafana for alerting and to detect endpoints downtime.
* Set up tools to collect, store and analyze logs from EKS and workloads, e.g: AWS CloudWatch Logs, ELK stack or Splunk.
* Set up workload's persistent volumes backups if there are shared persistent volumes.
* Set up PostgreSQL databases backups using [Barman](https://pgbarman.org/) or similar tools. Cloud Native PG can be [configured](https://cloudnative-pg.io/documentation/1.16/backup_recovery/) to back up databases using Barman.
* Traffic between pods on different nodes should use mutual TLS. Istio can be used for this. 
* Update Cert Manager to provision certificates from a trusted CA Authority.
* Change the Subnet's NAT Gateway Terraform configuration to have one NAT gateway in each availability zone as explained [here](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest).
* Deploy Isto to inspect and monitor pods to pods traffic. Istio installs an envoy proxy as a sidecar to intercept traffic across pods.
* Setup proper liveness probes for each deployment.
* Configure security contexts for deployments: deny privilege escalation, make sure apps are not running as root users and set read only root file system.
* Restrict containers access to underlying systems by configuring [Apparmor](https://kubernetes.io/docs/tutorials/security/apparmor/#:~:text=AppArmor%20can%20be%20configured%20for,access%2C%20file%20permissions%2C%20etc).  
* Set up cluster Network Policies: for example allow ingress traffic to database pods only from pods labelled with `type=backend` and only on port `5432`.
* Set up a Web Application Firewall (e.g. AWS [WAF](https://aws.amazon.com/it/blogs/containers/protecting-your-amazon-eks-web-apps-with-aws-waf/)) to protect from DDoS attacks and common web exploits that could affect application availability.
* Set up disaster recovery procedures and scripts to automatically recreate an environment starting from backups.
* Use a Vault Provider (e.g. Terraform Vault or AWS Secrets Manager) to securely store deployments secrets (database passwords, openid client secrets,...).

## High Availability, Security, Scalability and Disaster Recovery

### High Availability

EKS Control Plane HA:

The Kubernetes control plane managed by EKS runs inside a dedicated EKS managed VPC.
The EKS control plane which includes Kubernetes API server nodes and etcd cluster nodes runs in an auto-scaling group that spans three AZs as shown below:
![EKS Cluster Control Plane](assets/eks-data-plane-connectivity.jpeg)
Please note that this part of the infrastructure it is automatically created and managed by AWS whenever
an EKS cluster is created. This also explains why if we run `kubectl get pods -n kube-system` we only see the **kube-proxy** pods and not the **api-server** or **etcd** pods in the namespace.
The **kubelet** runs as a daemon on each node, can be checked running `systemctl status kubelet`.


Traefik Ingress HA:

High Availability is guaranteed by the provisioned AWS ALB when the Traefik ingress controller creates the LoadBalancer type Traefik service. 
We can test it by running dig:
```bash
$ dig +short a376b0b86319f4ccf935f1e2657e2b2f-634468632.eu-south-1.elb.amazonaws.com
18.102.99.115
18.102.191.156
18.102.180.48
```
This means that the Load Balancer DNS maps to 3 distinct IPs for HA, each corresponding to an AZ within the VPC.
For HA Traefik must be configured with replicas > 1 if  kind == Deployment or use deployment type DaemonSet.

Workloads HA: 

High Availability can be achieved by making sure workloads deployments have replicas >= 2 and correct topology spread constraints as described above.
A [Kubernetes Admission Controller](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/) can be used to effectively enforce that
all deployments installed on the cluster meet these requirements.

Database HA:

Cloud Native PG provides HA by exposing a single service endpoint which automatically failovers (and promotes a read replica to master) whenever the master database node is unavailable. 
Database replicas are kept in sync with master using quorum-based sync replication. For this reason  would be advisable to have 1 master and at least 3 replicas. Asynchronous replication is available as well.

Regional HA:

The current EKS cluster setup does not provide HA in case of a **regional failure**. For HA across region failures an identical cluster
must be setup in a different region. It could be a down scaled version of the original cluster with replicas at minimum or even 0 replicas but
ready to be bootstrapped. If the RTO (Recovery Time Objective) is short, it is important to have database continuously replicated
into the backup cluster. Cloud Native PG supports [Replicas Cluster](https://cloudnative-pg.io/documentation/1.18/replica_cluster/) useful when the target replica runs in a different region.

If the primary cluster goes down, the DNS records pointing to the Load Balancer of cluster 1 must be updated to point to cluster 2 Load Balancer.
There are different strategies to achieve this, a couple of examples are:
- Route53 DNS [active-passive failover](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover-types.html#dns-failover-types-active-passive): in this case it is important defining the correct endpoint to be used as a Healthcheck.
- Lambda function updating Route53 DNS record: a lambda function triggered on an S3 event fired when a file is uploaded on specific disaster recovery bucket. 
The lambda function would then immediately update the Route53 DNS record using AWS SDK for python for instance. 
In this case an on-call SRE would need to manually upload the file on the S3 bucket whenever an outage is detected, or it could just be uploaded on S3 by a specific CI/CD pipeline.


### Security

PODs security:

As outlined in the production readiness section above, pod security can be increased by configuring security contexts for deployments: deny privilege escalation, make sure apps are not running as root users and set read only root file system.
These security contexts can be enforced on the cluster by creating admission controllers checking these properties on the deployed workloads.

Another security aspect to consider is having pods using only Docker images from a trusted company repository. 
To enforce this an [ImagePolicyWebook](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#imagepolicywebhook) admission controller can be used.

To detect runtime threats within and across containers in the cluster, [Falco](https://falco.org/) can be used. 
It uses eBPF to intercept syscalls to detect for instance if a new process is spawned from within a container, 
or if an unexpected connection was opened on an unexpected port by a process.

To restrict containers access to the underlying system [AppArmor](https://apparmor.net/) can be used. 
AppArmor allows to whitelist or blacklist syscalls from a container or use predefined profiles. 
Securing pods with AppArmor is relatively simple, it just requires an annotation to be added to the pod's [metadata](https://kubernetes.io/docs/tutorials/security/apparmor/#securing-a-pod).
This solution requires having cluster nodes with apparmor installed, therefore a custom image is required.


External Network security:

As outlined in the production readiness section above, network security for traffic coming from outside the cluster (users)
can be tightened using Layer 7 firewalls specifically to protect against common web exploits: Injection Attacks, HTTP DDoS, Server-Side Request Forgery (SSRF), ...
Moreover, internal tools and dashboards, such as ArgoCD can be exposed on the same Ingress Load Balancer, however access should be restricted only from internal company IP networks.
This could be done at the firewall level (better) but also from Traefik ingress configuration, using source [IP WhiteList](https://doc.traefik.io/traefik/middlewares/http/ipwhitelist/).


Internal Network security:

Internal network security strategies include: defining Kubernetes network policies to restrict access from/to services and databases as discussed in the production readiness section above, 
but also by encrypting traffic using Mutual TLS between pods communications. 
Istio provides this [feature](https://istio.io/latest/docs/concepts/security/#mutual-tls-authentication) out of the box.
Another aspect to consider is using an [Egress Gateway](https://istio.io/latest/blog/2019/egress-traffic-control-in-istio-part-1/) to secure traffic 
leaving the cluster. This is particularly useful when workloads access external services.
If there are workloads using buckets or other cloud resources such as s3 buckets, it would be a good practice to configure [VPC or Gatway endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html),
so that traffic to these services does not leave AWS network (this also allows to save costs in transferring data from s3).

### Scalability

EKS Scalability:

The EKS managed node groups [scales](https://docs.aws.amazon.com/eks/latest/userguide/autoscaling.html#cluster-autoscaler) according to the amount of resources needed. If the Kubernetes Horizontal Pod Autoscaler
creates new pods and there aren't enough nodes to host the new pod, the EKS managed node groups spins-up a new node to accommodate
the pod (assuming the max size hasn't been reached yet).

Workloads scalability:

Scalability for workloads might depend on serveral factors. If the workloads are CPU bound, then HPA could be configured to scale
on target CPU utilization. If workloads are Memory bound, then HPA could be configured on memory utilization. Other metrics
can be considered as well, depending on the use case. A common approach is to scale worker pods based on the **number of messages
pending** in a queue. If there are more messages waiting, then pods processing the messages need to be increased to accommodate the load.

Database scalability:

In case of scalability for *reads*, read replicas can be increased in the database cluster.
For *writes* it would be necessary to provide a more powerful VMs running the database, hence would be scaling vertically with some downtime.

Persistent Volumes:

Scalability for Persistent Volumes depends on the storage class support for volume expansion. 
Using kubectl we can check it by running: 
```bash
> kubectl get storageclasses.storage.k8s.io 
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION 
gp2 (default)   kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                
```

### Disaster Recovery

Disaster recovery strategies depends on RTO (Recovery Time Objectives), RPO (Recovery Point Objectives) and costs:
- Recovery Time Objective (RTO): is the maximum acceptable delay between the interruption of service and restoration of service. This determines what is considered an acceptable time window when service is unavailable. This is defined by the organization considering customers SLAs as well.
- Recovery Point Objective (RPO): is the maximum acceptable amount of time since the last data recovery point. This determines what is considered an acceptable loss of data between the last recovery point and the interruption of service.

The disaster recovery strategies are categorized as:
- Backup & Restore: it is the cheapest and consists on recovering the system starting from backups taken regularly across the systems, databases and volumes, RTO high, RPO high. This strategy is only recommended for lower priority use cases as it might take a few hours to restore the systems.
- Pilot Light: with this approach the data is continuously replicated, but the workloads are not running in the backup cluster, except for the Database. The RTO could be 10/30 minutes, depending on the systems. Compared to the Backup & Restore this approach is more expensive.
- Warm Standby: with this approach the data is continuously replicated and a **minimum** set of workloads is running, ready to receive traffic. Compared to Pilot Light this approach reduces the RTO time as there are pods always ready to receive traffic. This approach is more expensive compared to Pilot Light. 
- Multi-Site active/active: with this approach a full replica of the first cluster is available. This approach has the lowest RTO and RPO, however it is the most expensive.

For a successful disaster recovery plan it is important to have a procedure to follow, describing all the steps and people involved
in the disaster recovery procedures.
