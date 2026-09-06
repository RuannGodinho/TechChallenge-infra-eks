# ADR – Orquestramos a API no Amazon EKS

| Campo | Valor |
|---|---|
| **Número** | 007 |
| **Data** | 21/08/2026 |
| **Dono** | Ruann Correa Godinho |
| **Status** | Aceita |
| **RFC de origem** | [RFC-007](../rfcs/007-orquestracao-eks.md) |

## Contexto

O challenge exige containerização e orquestração: restart, várias réplicas, PVC e autoscaling. Compose na EC2 não demonstra Kubernetes. O pod deve ser backend do API Gateway, não a entrada pública. A nuvem já é AWS ([ADR-001](001-adocao-aws.md)).

## Decisão

Rodamos a API e o Mongo de laboratório no cluster **Amazon EKS** `techchallenge-eks` (`us-east-1`). VPC, nodes e EBS CSI ficam no Terraform **deste** repositório. Os manifests da API ficam em `k8s/` no [TechChallenge-Fiap](https://github.com/RuannGodinho/TechChallenge-Fiap). O Compose permanece só no desenvolvimento local, com o mesmo Dockerfile.

## Consequências

Ganhamos rollout, HPA e persistência versionados. O mesmo artefato sobe no notebook e no cluster. Pagamos o control plane enquanto o EKS existir e aceitamos operação com `kubectl`/IAM. Um node de laboratório não prova multi-AZ.

## Alternativas

Descartamos ECS/Fargate porque o entregável pede Kubernetes. Descartamos kubeadm self-managed. Descartamos Compose-only na EC2. Descartamos OpenShift/k3s fora da AWS.
