# Rinha de Backend 2026 - linguagem Rinha

Implementação para a [Rinha de Backend 2026](https://github.com/zanfranceschi/rinha-de-backend-2026) com API e load balancer escritos em [Rinha](https://github.com/cleissonbarbosa/rinha-de-compiler/blob/main/SPECS.md), executados por uma versão estendida do meu [interpretador Haskell](https://github.com/cleissonbarbosa/rinha-compiladores-haskell) da [Rinha de Compiladores](https://github.com/aripiprazole/rinha-de-compiler).

A solução usa handoff de conexões via Unix domain socket, respostas HTTP precomputadas, keep-alive e busca vetorial IVF em arquivos `mmap`. A lógica de roteamento, balanceamento e montagem de resposta fica em [Rinha](https://github.com/cleissonbarbosa/rinha-de-compiler/blob/main/SPECS.md); o runtime expõe apenas primitivos nativos para sockets, strings, parse HTTP e score vetorial.

## Stack

| Camada | Tecnologia | Por que |
| --- | --- | --- |
| Load balancer | Rinha (`rinha/lb.rinha`) + sockets nativos | accept TCP em `:9999`, round-robin, envio do fd aceito para as APIs via `SCM_RIGHTS` e fallback de proxy TCP |
| API x2 | Rinha (`rinha/server.rinha`) + [interpretador Haskell](https://github.com/cleissonbarbosa/rinha-compiladores-haskell) da [Rinha de Compiladores](https://github.com/aripiprazole/rinha-de-compiler) estendido | keep-alive HTTP, roteamento de `/ready` e `/fraud-score`, respostas estaticas e execução longa |
| Runtime | Haskell (`rinha-compiladores`, branch `ext`) | builtins de socket, string, env, `http_parse_request`, `fraud_count_json` e aquecimento do indice |
| Busca vetorial | IVF nativo + `resources/*.bin` | dataset pre-processado, consulta kNN e refinamento sem reler arquivos no request path |
| Build | AST JSON precompilado + Docker | `.rinha` vira `build/*.json`; a imagem copia o runtime e os ASTs ja validados |

## Documentação

- [Documentação tecnica](docs/tecnical.md)
