# TechChallenge-infra-eks

Infraestrutura Kubernetes (Amazon EKS) em Terraform: VPC, cluster, node group, addons (vpc-cni, CoreDNS, EBS CSI) e parâmetros SSM para os repositórios irmãos.

> **Não aplique este stack contra o state de produção (`eks/terraform.tfstate`) enquanto o monorepo [TechChallenge-Fiap](https://github.com/RuannGodinho/TechChallenge-Fiap) ainda gerenciar o cluster.** O backend padrão usa `split/eks/terraform.tfstate`. O workflow recusa a key de produção.

## Repositórios

| Repo | Função |
|---|---|
| [TechChallenge-Fiap](https://github.com/RuannGodinho/TechChallenge-Fiap) | Aplicação Node + manifests K8s (Mongo in-cluster por enquanto) |
| **este** | Terraform EKS / VPC |
| [TechChallenge-lambda-auth](https://github.com/RuannGodinho/TechChallenge-lambda-auth) | Lambda JWT + API Gateway |
| [TechChallenge-infra-db](https://github.com/RuannGodinho/TechChallenge-infra-db) | Terraform MongoDB Atlas (opt-in) |

## Contratos publicados no SSM

Prefixo padrão `/techchallenge`:

- `/techchallenge/eks/cluster_name`
- `/techchallenge/eks/aws_region`
- `/techchallenge/eks/vpc_id`
- `/techchallenge/eks/public_subnet_ids`
- `/techchallenge/eks/node_security_group_id`
- `/techchallenge/eks/backend_url` — `http://<node-public-ip>:30080`

## CI/CD

| Workflow | Gatilho | Efeito |
|---|---|---|
| CI | push/PR | `fmt` + `validate` (sem backend) |
| Terraform Bootstrap | manual | bucket S3 de state (já existente no monorepo — não rode apply se o bucket já existe) |
| Terraform | manual `plan` / `apply` / `destroy` | `apply` e `destroy` exigem `confirm=yes` |

### Secrets / variables

- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- `TF_STATE_BUCKET` ou `TF_BACKEND_HCL`
- `TF_AWS_REGION` (default `us-east-1`)
- `TF_STATE_KEY` deve ser `split/eks/terraform.tfstate` até o cutover

## Apply local

```bash
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl   # ajustar bucket
terraform init -backend-config=backend.hcl
terraform plan
```
