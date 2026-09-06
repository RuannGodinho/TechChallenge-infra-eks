# Documentação — TechChallenge-infra-eks

Este repositório documenta a **nuvem AWS**, o **cluster EKS** e o **Terraform** da Node-Fiap. A API, o login JWT e o Atlas moram nos [repositórios irmãos](../README.md).

Índice da solução (checklist do enunciado): [TechChallenge-Fiap / docs/ARQUITETURA.md](https://github.com/RuannGodinho/TechChallenge-Fiap/blob/main/docs/ARQUITETURA.md).

| Documento | Conteúdo |
|---|---|
| [RFCs](rfcs/README.md) | Nuvem (001), EKS (007), NodePort (008), Terraform (010) |
| [ADRs](adrs/README.md) | Decisões permanentes correspondentes |
| [TERRAFORM.md](TERRAFORM.md) | Bootstrap S3, state, apply do cluster |

## O que não fica aqui

| Assunto | Repositório |
|---|---|
| Diagrama de componentes, OS, modelo de dados, HPA da API | [TechChallenge-Fiap](https://github.com/RuannGodinho/TechChallenge-Fiap/tree/main/docs) |
| Sequência de autenticação, JWT, API Gateway | [TechChallenge-lambda-auth](https://github.com/RuannGodinho/TechChallenge-lambda-auth/tree/main/docs) |
| MongoDB / Atlas | [TechChallenge-infra-db](https://github.com/RuannGodinho/TechChallenge-infra-db/tree/main/docs) |
