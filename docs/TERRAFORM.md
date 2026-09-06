# Provisionamento com Terraform

Este repositório cria o **bucket de state** (`bootstrap/`) e o **cluster EKS** (VPC, nodes, addons, SSM `/techchallenge/eks/*`).

State: `eks/terraform.tfstate` no bucket compartilhado. **Não** use essa key no apply das Lambdas nem do Atlas.

| Stack | Repositório | State key |
|---|---|---|
| VPC, EKS, SSM `backend_url` | **este** | `eks/terraform.tfstate` |
| Lambdas JWT + API Gateway | [TechChallenge-lambda-auth](https://github.com/RuannGodinho/TechChallenge-lambda-auth) | `lambda-auth/terraform.tfstate` |
| MongoDB Atlas M0 (opt-in) | [TechChallenge-infra-db](https://github.com/RuannGodinho/TechChallenge-infra-db) | ver aquele repo |
| Workloads API / Mongo in-cluster / HPA | [TechChallenge-Fiap](https://github.com/RuannGodinho/TechChallenge-Fiap) `k8s/` | — (kubectl, não Terraform) |

Decisão: [RFC-010](rfcs/010-terraform-iac.md) / [ADR-010](adrs/010-terraform-iac.md). Passo a passo de apply: [README](../README.md).
