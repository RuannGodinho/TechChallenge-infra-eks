# TechChallenge-infra-eks

Infraestrutura Kubernetes da **oficina Node-Fiap** em Terraform: VPC, cluster Amazon EKS, node group, addons e parâmetros SSM para os repositórios irmãos.

Este repositório entrega **somente o cluster**. API, login JWT e Mongo vivem nos [repositórios irmãos](#repositórios-irmãos).

> **Não aplique este stack contra o state de produção (`eks/terraform.tfstate`) enquanto o monorepo [TechChallenge-Fiap](https://github.com/RuannGodinho/TechChallenge-Fiap) ainda gerenciar o cluster.** O backend padrão usa `split/eks/terraform.tfstate`. O workflow recusa a key de produção.

## Propósito

- Provisionar a VPC, o EKS e o node group usados pela API e pelo Mongo in-cluster.
- Publicar no SSM o contrato que os outros repos leem (`cluster_name`, `backend_url`, subnets, security group).
- Manter o state Terraform isolado no bucket compartilhado (`eks/terraform.tfstate` após o cutover).

Decisões: [RFC-001](docs/rfcs/001-adocao-aws.md), [RFC-007](docs/rfcs/007-orquestracao-eks.md), [RFC-008](docs/rfcs/008-nodeport-sem-alb.md), [RFC-010](docs/rfcs/010-terraform-iac.md).

## Tecnologias

| Camada | Tecnologia |
|---|---|
| Nuvem | AWS (`us-east-1`) |
| Rede | VPC, subnets públicas, security groups |
| Orquestração | Amazon EKS + managed node group |
| Addons | vpc-cni, CoreDNS, EBS CSI |
| Config | SSM Parameter Store `/techchallenge/eks/*` |
| Estado | S3 (`use_lockfile`) |
| IaC | Terraform 1.11 |
| CI/CD | GitHub Actions (CI + Terraform manual + bootstrap) |

## Arquitetura deste repositório

O que **este** repo cria. Workloads da API e do Mongo são `kubectl` em outros repos.

```mermaid
flowchart TB
  subgraph thisrepo [Este repositório — Terraform]
    S3[(S3 terraform state<br/>eks/terraform.tfstate)]
    VPC[VPC + subnets públicas]
    EKS[Amazon EKS<br/>techchallenge-eks]
    NG[Managed node group]
    ADD[Addons<br/>vpc-cni / CoreDNS / EBS CSI]
    SSM[SSM /techchallenge/eks/*<br/>cluster_name backend_url vpc_id]
    VPC --> EKS --> NG
    EKS --> ADD
    EKS --> SSM
    S3 --- EKS
  end

  subgraph siblings [Repos irmãos — não sobem aqui]
    API[TechChallenge-Fiap<br/>Deployment API + HPA]
    DB[TechChallenge-infra-db<br/>mongo-service + PVC]
    GW[TechChallenge-lambda-auth<br/>API Gateway]
  end

  SSM -->|backend_url| GW
  SSM -->|kubeconfig| API
  SSM -->|kubeconfig| DB
  NG --> API
  NG --> DB
```

Diagrama da solução inteira: [componentes no Fiap](https://github.com/RuannGodinho/TechChallenge-Fiap/blob/main/docs/ARQUITETURA-COMPONENTES.md). Passo a passo do state: [docs/TERRAFORM.md](docs/TERRAFORM.md).

## Requisitos

- Terraform 1.11
- AWS CLI configurada (conta com permissão de EKS, VPC, IAM, SSM, S3)
- Arquivos `terraform.tfvars` e `backend.hcl` a partir dos `.example`
- Bucket S3 de state (workflow **Terraform Bootstrap**, ou o bucket já existente do monorepo)

Não precisa de Node, Docker nem kubectl para o *apply* deste repo. `kubectl` entra só depois, nos repos da API e do banco.

## Execução local

```text
*.tf                  # VPC, cluster, storage, SSM, outputs
bootstrap/            # bucket S3 do state (uma vez)
docs/                 # RFCs, ADRs, TERRAFORM.md
```

```bash
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl   # ajustar bucket
terraform init -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
terraform plan
```

### Contratos publicados no SSM

Prefixo padrão `/techchallenge`:

- `/techchallenge/eks/cluster_name`
- `/techchallenge/eks/aws_region`
- `/techchallenge/eks/vpc_id`
- `/techchallenge/eks/public_subnet_ids`
- `/techchallenge/eks/node_security_group_id`
- `/techchallenge/eks/backend_url` — `http://<node-public-ip>:30080`

## Deploy

1. Bootstrap do bucket (se ainda não existir): workflow **Terraform Bootstrap** — **não** rode apply se o bucket já existe.
2. `terraform apply` deste repo (local ou workflow **Terraform** com `confirm=yes`).
3. Só então: Mongo (`TechChallenge-infra-db`) → API (`TechChallenge-Fiap`) → Gateway (`TechChallenge-lambda-auth`).

```bash
terraform apply
aws eks update-kubeconfig --region us-east-1 --name techchallenge-eks
kubectl get nodes
```

`TF_STATE_KEY` deve ser `split/eks/terraform.tfstate` até o cutover; depois `eks/terraform.tfstate`. Detalhe: [docs/TERRAFORM.md](docs/TERRAFORM.md).

## Pipeline

| Workflow | Gatilho | Efeito |
|---|---|---|
| CI (`.github/workflows/ci.yml`) | push/PR | `terraform fmt` + `validate` (sem backend) |
| Terraform Bootstrap | `workflow_dispatch` | bucket S3 de state |
| Terraform | `workflow_dispatch` plan / apply / destroy | `apply` e `destroy` exigem `confirm=yes` |

### Secrets / variables

- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- `TF_STATE_BUCKET` ou `TF_BACKEND_HCL`
- `TF_AWS_REGION` (default `us-east-1`)
- `TF_STATE_KEY` — `split/eks/terraform.tfstate` até o cutover

## Repositórios irmãos

| Repositório | Papel |
|---|---|
| [TechChallenge-Fiap](https://github.com/RuannGodinho/TechChallenge-Fiap) | API Node + manifests K8s |
| [TechChallenge-lambda-auth](https://github.com/RuannGodinho/TechChallenge-lambda-auth) | JWT + API Gateway |
| [TechChallenge-infra-db](https://github.com/RuannGodinho/TechChallenge-infra-db) | Mongo no EKS + Atlas opt-in |

## Documentação

| Documento | Conteúdo |
|---|---|
| [docs/](docs/README.md) | Índice deste repo |
| [TERRAFORM.md](docs/TERRAFORM.md) | Bootstrap S3, state, apply |
| [RFC-001](docs/rfcs/001-adocao-aws.md) / [ADR-001](docs/adrs/001-adocao-aws.md) | Adoção AWS |
| [RFC-007](docs/rfcs/007-orquestracao-eks.md) / [ADR-007](docs/adrs/007-orquestracao-eks.md) | EKS |
| [RFC-008](docs/rfcs/008-nodeport-sem-alb.md) / [ADR-008](docs/adrs/008-nodeport-sem-alb.md) | NodePort sem ALB |
| [RFC-010](docs/rfcs/010-terraform-iac.md) / [ADR-010](docs/adrs/010-terraform-iac.md) | Terraform |
| [Índice da solução](https://github.com/RuannGodinho/TechChallenge-Fiap/blob/main/docs/ARQUITETURA.md) | Checklist do enunciado |

## Integração dos três serviços

O NodePort original 30080 (Orders) é preservado. Execution usa 30081 e Billing 30082, liberados pelo mesmo allowed_api_cidr; os Services correspondentes ficam nos repositórios de aplicação. api_node_port, execution_node_port e billing_node_port devem coincidir com esses manifests.

SSM publica /techchallenge/eks/backend_url, /techchallenge/eks/execution_backend_url e /techchallenge/eks/billing_backend_url, além dos outputs Terraform correspondentes. As três URLs usam o mesmo IP público de node selecionado pelo padrão existente. Após substituição do node (inclusive Spot), atualizar o Terraform deste repo e do lambda-auth para atualizar SSM/integrações; esse padrão não oferece endpoint estável por si só.

Sem novo cluster, load balancer ou alteração de quantidade/tipo de nodes/discos. A versão do Kubernetes segue a configuração e o procedimento de atualização abaixo. Os aplicativos têm 6 pods base e HPA 1–4 por API; bancos/broker e componentes de sistema são adicionais. O limite de HPA não assegura capacidade de nodes. Revisar o plano antes de apply e medir capacidade no cluster. Perfis de capacidade e estados existentes são preservados.

## Versão do EKS e atualização

O alvo padrão e o terraform.tfvars.example usam **1.37**, em suporte padrão até 01/12/2027 no [calendário EKS](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html), consultado em 16/11/2026. Isso evita a tarifa de suporte estendido da 1.31 após a implantação; a alteração de arquivos não muda a cobrança de um cluster existente.

O managed node group acompanha aws_eks_cluster.main.version. VPC CNI, CoreDNS e EBS CSI, já gerenciados neste stack, passam a resolver explicitamente a versão compatível padrão da AWS para kubernetes_version. Não foi adicionado outro componente. Quantidade/tipo de nodes, SPOT, volumes, HPA e estados permanecem iguais.

Para um **cluster novo**, revisar o plano com o alvo 1.37. Para um **cluster existente em 1.31**, não aplicar diretamente o alvo final: a AWS permite apenas um minor por etapa, seguindo 1.31 → 1.32 → 1.33 → 1.34 → 1.35 → 1.36 → 1.37. Antes de cada etapa, revisar Upgrade Insights, APIs removidas, versões dos nodes e compatibilidade dos add-ons; o apply não automatiza essa auditoria. Usar o backend/state que já possui o cluster, mantendo a proteção de state existente neste repo.

No fluxo CLI existente, um override permite revisar e aplicar cada etapa separadamente:

```bash
# Exemplo: apenas a primeira etapa de um cluster que ainda está em 1.31.
terraform plan -var='kubernetes_version=1.32' -out=upgrade.tfplan
terraform apply upgrade.tfplan
# Validar nodes, add-ons e workloads antes de planejar o próximo minor.
```

Não executar uma sequência automática sem validação intermediária. O workflow existente copia terraform.tfvars.example; portanto seu alvo padrão é 1.37 e ele não deve ser usado para saltar versões de um cluster antigo.

Os nodes atuais precisam estar no mesmo minor do control plane antes da próxima etapa. Conferir a AMI atual: Amazon Linux 2 não tem imagem EKS para 1.34+; caso um node group antigo use AL2, migrá-lo para AL2023 antes dessas etapas, em uma mudança própria, sem remover o grupo que ainda atende os pods. Ver [guia de atualização da AWS](https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html) e [notas das versões](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html).

kube-proxy não é gerenciado por este stack: verificar e atualizar a instalação existente em cada etapa. Validar também Metrics Server, New Relic, EBS CSI/PVCs, DNS e HPA no cluster. Validação local de Terraform e schemas não comprova o funcionamento desses componentes no EKS. Nenhum apply AWS foi executado nesta alteração.
