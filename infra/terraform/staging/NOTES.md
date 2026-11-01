# SRE EKS Playground

# Outpus
```sh
cluster_role_arn = "arn:aws:iam::410870066601:role/sre-playground-staging-cluster-role"
db_subnet_ids = [
  "subnet-029ac7de97f15b808",
]
node_role_arn = "arn:aws:iam::410870066601:role/sre-playground-staging-node-role"
private_subnet_ids = [
  "subnet-05daffb5521c60b28",
  "subnet-00a12183684eeaf56",
]
public_subnet_ids = [
  "subnet-04774732eb8596833",
  "subnet-0a7de23e9a791b51e",
]
vpc_id = "vpc-06a0d9e5e1888c68f"
```

## Debug Commands

You don't write an access entry for nodes. The managed node group creates an EC2_LINUX access entry for the node role by itself. 
```sh
aws eks list-access-entries --cluster-name sre-playground-staging-eks-cluster.
```