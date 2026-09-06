# ADR – Exponos o cluster via NodePort, sem ALB

| Campo | Valor |
|---|---|
| **Número** | 008 |
| **Data** | 21/08/2026 |
| **Dono** | Ruann Correa Godinho |
| **Status** | Aceita |
| **RFC de origem** | [RFC-008](../rfcs/008-nodeport-sem-alb.md) |

## Contexto

O API Gateway precisa de uma URL HTTP estável (`backend_url` no SSM). Ingress + ALB é o padrão AWS, mas o load balancer cobra por hora e soma ao control plane EKS no orçamento de estudante.

## Decisão

Exponos a API com Service **NodePort `30080`** apontando para o container `:3000`. Não usamos Application Load Balancer nem Ingress neste recorte. O cliente de produção continua falando só com o API Gateway. A confiança no hop Gateway → node é o header `x-gateway-trust`.

## Consequências

Eliminamos o custo do ALB e simplificamos o manifest. Em troca, o IP do node pode mudar, o hop é HTTP (sem TLS) e a porta 30080 é superfície se o Security Group estiver aberto. Debug com `curl` no node fica trivial.

## Alternativas

Descartamos Ingress + AWS Load Balancer Controller e Service `LoadBalancer`/NLB por custo. Descartamos ClusterIP + VPC Link pela complexidade no HTTP API atual. Descartamos somente port-forward, que não serve como `backend_url`.
