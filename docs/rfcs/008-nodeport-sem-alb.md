# RFC – Exposição do cluster via NodePort (sem Ingress/ALB)

**Casa:** Security Group e `backend_url` neste repo. Service `k8s/Api-service.yml`: [TechChallenge-Fiap](https://github.com/RuannGodinho/TechChallenge-Fiap).

| Campo | Valor |
|---|---|
| **Número** | 008 |
| **Data** | 21/08/2026 |
| **Autor** | Ruann Correa Godinho |
| **Status** | Encerrada – Aprovada |
| **ADR** | [ADR-008](../adrs/008-nodeport-sem-alb.md) |

## Resumo

Expor a API no EKS com Service **NodePort `30080`** → container `:3000`. Não usar Application Load Balancer nem Ingress neste recorte, para evitar custo horário de LB. O **API Gateway** continua sendo a entrada HTTPS dos clientes.

## Problema

O pod precisa ser alcançável pelo API Gateway (integração HTTP) e, em emergência de lab, pelo IP do node. Ingress + ALB é o padrão AWS, mas o load balancer cobra enquanto existe — somado ao control plane EKS, estoura o orçamento de estudante.

Sem um Service, o Gateway não tem URL estável (`backend_url` no SSM).

## Proposta técnica

- `k8s/Api-service.yml`: `type: NodePort`, `nodePort: 30080`.
- Terraform/EKS publica `/techchallenge/eks/backend_url` apontando para `http://<node-ip>:30080`.
- Clientes de produção **não** usam essa URL: usam o API Gateway. O NodePort é o hop interno da borda.
- Confiança no hop: `x-gateway-trust` ([RFC-003 no lambda-auth](https://github.com/RuannGodinho/TechChallenge-lambda-auth/blob/main/docs/rfcs/003-autenticacao-jwt-api-gateway.md)), não TLS de sidecar.

```text
Cliente --HTTPS--> API Gateway --HTTP--> NodeIP:30080 --> Pod:3000
```

## Impacto esperado

**Ganhos**

- Zero ALB no billing.
- URL simples para o Gateway e para `curl` de debug no node.
- Manifest mínimo, fácil de ensinar.

**Riscos e restrições**

- IP do node muda se o node for substituído — `backend_url` precisa ser atualizado.
- Porta 30080 pública se o Security Group permitir `0.0.0.0/0`; a mitigação é SG restrito + trust header.
- Sem TLS no hop Gateway → node (HTTP). Aceitável em lab; inadequado em produção comercial.
- Health check do Gateway depende do node estar saudável; não há ALB distribuindo entre AZs.

## Alternativas consideradas

| Alternativa | Por que foi descartada |
|---|---|
| **Ingress + AWS Load Balancer Controller (ALB)** | Caminho “certo” em AWS. Custo do ALB + controller + anotações não se justificam no lab. |
| **NLB / Service `LoadBalancer`** | Mesmo problema de custo; NLB não termina HTTP como o Gateway já faz. |
| **ClusterIP + VPC Link** | Mais seguro (sem IP público do node). Exige API Gateway REST/VPC Link ou Private Integration — setup mais longo que o HTTP API atual. |
| **Port-forward / bastion só** | Não serve como `backend_url` permanente para o Gateway. |

## Pontos em aberto

- Restringir o Security Group da porta `30080` ao prefixo do API Gateway (ou NAT do execute-api).
- Promover a Ingress/ALB se houver crédito e exigência de TLS no hop.
- Elastic IP ou node estável para não invalidar o SSM a cada scale-down.
