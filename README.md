# Rinha de Backend 2026 - linguagem Rinha

Port da [Rinha de Backend 2026](https://github.com/zanfranceschi/rinha-de-backend-2026)
em que **a API e o load balancer sao escritos em Rinha** - a linguagem da
[Rinha de Compiladores](https://github.com/aripiprazole/rinha-de-compiler) -
e executados por uma versao estendida do interpretador
[`cleissonbarbosa/rinha-compiladores-haskell`](https://github.com/cleissonbarbosa/rinha-compiladores-haskell).

Localmente, este projeto usa o interpretador em `~/Documents/rinha-compiladores-haskell`
para gerar `build/server.json` e `build/lb.json`. As imagens Docker baixam o
interpretador direto do GitHub, na branch `ext`, e copiam esses ASTs
precompilados para dentro do container.

## O que roda em Rinha

Praticamente toda a logica de aplicacao vive em Rinha. O interpretador so
expoe primitivos que nao da para escrever na linguagem: sockets crus, bytes de
string, variaveis de ambiente e o indice vetorial nativo.

[`rinha/server.rinha`](rinha/server.rinha) e a **API inteira**, escrita em Rinha:

1. escuta TCP com `net_listen_addr`/`net_serve` e aquece o indice com `ivf_warmup`;
2. **parseia a request HTTP** (request line, `Content-Length`, separacao
   header/corpo) lendo os bytes do socket com `net_recv`;
3. **parseia o JSON** da transacao e as datas ISO-8601 byte a byte;
4. **normaliza** os 14 eixos do vetor-query;
5. **vetoriza**, chama `ivf_query` e roda o **kNN** sobre os candidatos;
6. **monta a resposta HTTP** e responde mantendo a conexao keep-alive.

[`rinha/lb.rinha`](rinha/lb.rinha) e o load balancer TCP: accept loop,
round-robin, fallback entre backends, relay bidirecional com `net_recv`/
`net_send` e fechamento de sockets.

A linguagem Rinha original so tem `Print`. Para viabilizar um servidor real, o
interpretador foi estendido com alguns **builtins nativos** - mas apenas
primitivos de baixo nivel, sem regra de negocio:

| Builtin | Efeito |
| --- | --- |
| `read_input(_)` | le toda a entrada padrao e devolve uma string |
| `str_chars(s)` | converte uma string numa lista Rinha de codigos de byte |
| `str_from_chars(l)` | operacao inversa de `str_chars` |
| `str_byte(n)` | cria uma string de 1 byte (usado para aspas/CRLF) |
| `str_len(s)` | tamanho de uma string em bytes |
| `env`, `env_int` | le variaveis de ambiente |
| `net_listen_addr`, `net_serve` | escuta TCP e accept loop thread-por-conexao |
| `net_recv`, `net_send`, `net_close`, `net_shutdown` | I/O de socket cru |
| `net_connect_addr` | conexao para backends |
| `spawn`, `counter_new`, `counter_next` | concorrencia/estado atomico minimo |
| `ivf_query(dvec, n)` | recupera candidatos do indice IVF nativo (mmap) |
| `ivf_warmup()` | mapeia o indice antes de aceitar trafego |

Nao ha mais builtins de HTTP (`http_read_request`/`http_send_json`) nem de
fraude (`fraud_score_json`): roteamento, parse HTTP, parse JSON, normalizacao,
vetorizacao e kNN agora rodam todos dentro de `rinha/server.rinha`.

As extensoes do interpretador vivem na branch `ext` do repositorio
`~/Documents/rinha-compiladores-haskell`. O parser (`.rinha` -> AST JSON) fica
em `~/Documents/rinha-de-compiler`; ele aceita `record { ... }` e acesso por
campo `obj.campo`, e os operadores aritmeticos/logicos sao **associativos a
esquerda** (`a - b - c` = `(a - b) - c`).

## Arquitetura

| Camada | Tecnologia | Papel |
| --- | --- | --- |
| Load balancer | Rinha (`rinha/lb.rinha`) | round-robin, fallback e relay TCP entre `api1` e `api2` |
| API HTTP | Rinha (`rinha/server.rinha`) | parse HTTP, parse JSON, normalizacao, vetorizacao, kNN e resposta |
| Interpretador | Haskell (`~/Documents/rinha-compiladores-haskell`, branch `ext`) | executa o programa Rinha |
| Indice vetorial | builtin Haskell `ivf_query` | 3M vetores, 8192 clusters via mmap |

Fluxo de um `POST /fraud-score`:

1. `rinha/lb.rinha` aceita a conexao e escolhe `api1` ou `api2`;
2. `rinha/lb.rinha` relaya os bytes entre cliente e backend com loops em Rinha;
3. `rinha/server.rinha` le e parseia a request HTTP, extrai metodo/rota/corpo;
4. `rinha/server.rinha` parseia o JSON, normaliza, vetoriza, chama `ivf_query`
   e calcula o voto kNN 0..5;
5. o handler responde `{"approved":bool,"fraud_score":float}` (approved se score < 0.6).

## Limite honesto do port

- Sockets e accept loop continuam expostos por builtins nativos; o protocolo
  HTTP (parse e resposta) esta em Rinha.
- O indice IVF continua nativo (mmap de ~84 MB de vetores + recuperacao de
  candidatos); a vetorizacao da transacao e o kNN dos candidatos estao em Rinha.
- Aritmetica em ponto-fixo (escala 4096): a linguagem so tem `Int`. O
  interpretador usa `Integer` (precisao arbitraria), entao nao ha overflow.
- `unknown_merchant` e resolvido por busca de substring do id do lojista
  dentro do array `known_merchants` da transacao.
- Nao ha cache de resultados: parse, normalizacao, `ivf_query` e kNN sao
  refeitos a cada request dentro de `rinha/server.rinha`.
- O interpretador continua tree-walking e long-running; e bem mais lento que
  uma implementacao nativa - o ponto do projeto e a logica estar em Rinha.

## Rodar local

```sh
make             # precompila server.rinha/lb.rinha para validar sintaxe
make up           # docker compose up --build -d
make smoke        # sobe tudo e exercita /ready + /fraud-score
make down
```

Endpoint publico no LB, porta `9999`:

```sh
curl -s http://localhost:9999/ready
curl -s -X POST http://localhost:9999/fraud-score \
  -H 'Content-Type: application/json' -d @transacao.json
```

Resposta:

```json
{"approved":false,"fraud_score":0.8}
```

## Validar o nucleo Rinha

`make rinha-check` precompila [`rinha/server.rinha`](rinha/server.rinha) e
[`rinha/lb.rinha`](rinha/lb.rinha) para o AST JSON oficial. O smoke test
(`make smoke`) cobre `/ready` e o caminho completo de `/fraud-score`.

## Variaveis de ambiente (API)

| Variavel | Padrao | Descricao |
| --- | --- | --- |
| `API_ADDR` | `0.0.0.0:8080` | endereco de escuta |
| `RESOURCES_DIR` | `resources` | dir com `vectors.bin`, `labels.bin`, `ivf.bin`, `*.json` |
| `KNN_CANDIDATES` | `128` | candidatos recuperados por request |
| `RINHA_PROBE` | `nprobe` do indice | clusters IVF sondados por request |

## Variaveis de ambiente (LB)

| Variavel | Padrao | Descricao |
| --- | --- | --- |
| `LB_ADDR` | `0.0.0.0:9999` | endereco de escuta |
| `BACKEND1` | `api1:8080` | primeiro backend |
| `BACKEND2` | `api2:8080` | segundo backend |
| `LB_CHUNK_SIZE` | `8192` | tamanho do buffer de relay por leitura |
