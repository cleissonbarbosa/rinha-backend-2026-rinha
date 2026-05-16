# Rinha de Backend 2026 - linguagem Rinha

Implementacao para a [Rinha de Backend 2026](https://github.com/zanfranceschi/rinha-de-backend-2026) com API e load balancer escritos em Rinha, executados por uma versao estendida do interpretador Haskell da [Rinha de Compiladores](https://github.com/aripiprazole/rinha-de-compiler).

A solucao usa handoff de conexoes via Unix domain socket, respostas HTTP precomputadas, keep-alive e busca vetorial IVF em arquivos `mmap`. A logica de roteamento, balanceamento e montagem de resposta fica em Rinha; o runtime expoe apenas primitivos nativos para sockets, strings, parse HTTP e score vetorial.

## Stack

| Camada | Tecnologia | Por que |
| --- | --- | --- |
| Load balancer | Rinha (`rinha/lb.rinha`) + sockets nativos | accept TCP em `:9999`, round-robin, envio do fd aceito para as APIs via `SCM_RIGHTS` e fallback de proxy TCP |
| API x2 | Rinha (`rinha/server.rinha`) + interpretador Haskell estendido | keep-alive HTTP, roteamento de `/ready` e `/fraud-score`, respostas estaticas e execucao longa |
| Runtime | Haskell (`rinha-compiladores`, branch `ext`) | builtins de socket, string, env, `http_parse_request`, `fraud_count_json` e aquecimento do indice |
| Busca vetorial | IVF nativo + `resources/*.bin` | dataset pre-processado, consulta kNN e refinamento sem reler arquivos no request path |
| Build | AST JSON precompilado + Docker | `.rinha` vira `build/*.json`; a imagem copia o runtime e os ASTs ja validados |

## Rodar

```sh
make              # valida server.rinha/lb.rinha e gera build/*.json
make up           # docker compose up --build -d e espera /ready
make smoke        # exercita /ready e /fraud-score
make official-test
make down
```

Endpoint publico no load balancer:

```sh
curl -s http://localhost:9999/ready
curl -s -X POST http://localhost:9999/fraud-score \
  -H 'Content-Type: application/json' \
  -d @transacao.json
```

## Documentacao

- [Documentacao tecnica](docs/tecnical.md)
