[English](README.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · **Português** · [Español](README.es.md)

# Pricing AI

O Pricing AI ajuda pequenos negócios de serviços e estúdios de software a definir preços com segurança: calcula quanto cada serviço realmente custa, cria um site de reservas, faz orçamentos de projetos de software e mostra por quanto contratos públicos semelhantes em Taiwan foram adjudicados. A IA roda no seu próprio computador: seus dados não são enviados a uma IA na nuvem.

- Site: https://pricingai.minervaelectronics.com/pt/
- Baixar para macOS: https://github.com/matt-hima/pricing-ai/releases/latest
- Versão do navegador (sem IA, sem instalação): https://pricingai.minervaelectronics.com/app/?lang=pt

## Recursos

O app tem quatro abas.

### 1. Preços de serviços

Para salões, clínicas, restaurantes, escolas e espaços de aluguel.

- Informe seu valor por hora, custos fixos mensais, horas reserváveis, lucro-alvo, impostos e arredondamento.
- Para cada serviço, informe os minutos e os materiais; o app mostra o custo real, o preço que atinge sua margem e o lucro.
- Um resumo mostra o custo indireto por hora, o número de horas para empatar e o lucro mensal no seu plano.
- 14 moedas com seus impostos e arredondamentos usuais. Exporte um CSV ou adicione a lista de preços ao seu site de reservas com um clique.
- App desktop: a IA sugere serviços para o seu negócio, e "Pesquisar preços" busca na web quanto negócios semelhantes cobram e transforma os resultados em uma lista de preços (só são usados preços que aparecem nos resultados).

### 2. Criar site

- Comece com um modelo limpo em inglês, chinês tradicional, japonês, português ou espanhol e edite visualmente.
- Adicione serviços e preços, perguntas frequentes, fluxogramas e um visual tecnológico escuro.
- Receba reservas com o Google Forms: um Apps Script cria o formulário e uma agenda que mostra os horários ocupados, e cada reserva vira um evento.
- Exporte um ZIP para qualquer hospedagem.
- App desktop: descreva seu negócio em um chat e a IA escreve a página, reescreve partes e desenha imagens de banner; publique no Firebase com um clique.

### 3. Orçamento de projeto (desenvolvimento de software)

- Informe sua empresa, o valor do homem-mês e os impostos, o cliente e as condições do orçamento.
- Escolha o tipo de projeto, as plataformas (web, iOS, Android…), o nível de design e até 17 módulos de funcionalidades, cada um com observações em linguagem simples.
- Receba uma faixa de preço total (o limite superior inclui uma margem de risco de 1,2–1,5×), a divisão em homem-mês por fase, o prazo e as taxas de manutenção sugeridas.
- Orçamento em PDF ao vivo: visualize, baixe, imprima ou envie ao comercial.
- App desktop: a IA local divide cada módulo em subtarefas e estima as horas; os preços são sempre calculados pelo app a partir do seu valor, nunca pela IA.
- "Casos anteriores": abre o Sistema de Compras do governo de Taiwan para projetos semelhantes adjudicados e resume preços e concorrência ao lado do seu orçamento (veja abaixo).

### 4. Análise de licitações (compras públicas de Taiwan)

Recurso do app desktop. O Sistema de Compras Eletrônicas do governo (web.pcc.gov.tw) abre em um navegador dentro do app; você mesmo navega, e o app lê apenas as páginas que você abre.

- Expansão de palavras-chave seguindo a regra do site: ele compara o termo como uma frase contínua (espaços são ignorados), então variações como 網站 / 網頁 / 官網 são pesquisadas separadamente e combinadas.
- Valores adjudicados: quantidade, mediana, 50% centrais, média, faixa e distribuição, os órgãos que mais compram e as modalidades.
- Onde fica o seu orçamento: a parcela de casos semelhantes abaixo do seu preço e se ele está na faixa baixa, típica ou alta.
- Concorrência: abra alguns avisos de adjudicação para ver quantas empresas concorreram, quão perto do orçamento ficou o valor e quem venceu.
- Possíveis concorrentes: todos os licitantes dos avisos abertos; consulte o histórico de qualquer empresa nos últimos 12 meses (vitórias, propostas, taxa de vitória, valor típico, órgãos).
- O Google Modo IA abre no navegador do app para informações públicas sobre uma empresa ou um mercado, para você ler.
- Exporte os casos em CSV.

## App desktop ou navegador?

| Recurso | App desktop | Navegador |
|---|---|---|
| Calculadora de preços de serviços | ✓ | ✓ |
| Editor de site e exportação em ZIP | ✓ | ✓ |
| Orçamento de projeto pela tabela embutida | ✓ | ✓ |
| Orçamentos com IA e site escrito por chat | ✓ | — |
| Análise de licitações e resumo com IA | ✓ | — |
| Histórico de concorrentes e Google Modo IA | ✓ | — |
| Publicação no Firebase com um clique | ✓ | — |
| Seus dados ficam no seu computador | ✓ | ✓ |

A versão do navegador, inclusive o atalho que o Chrome oferece instalar ("Pricing AI Web"), não é o app desktop.

## Baixar e instalar (macOS)

1. Baixe `PricingAI-mac.dmg` da [versão mais recente](https://github.com/matt-hima/pricing-ai/releases/latest).
2. Abra o .dmg e arraste o **Pricing AI** para **Aplicativos**.
3. Abra o Pricing AI. Esta versão ainda não é assinada com um Apple Developer ID, então na primeira vez o macOS pode dizer que não consegue verificar o desenvolvedor: abra **Ajustes do Sistema → Privacidade e Segurança** e clique em **Abrir Mesmo Assim** (só uma vez).
4. A primeira tarefa de IA baixa o motor e um modelo uma vez (0,5–5 GB). Depois, a IA roda no seu computador.

A versão para Windows chega em breve.

### Requisitos do sistema

| | |
|---|---|
| macOS | 10.15 ou posterior; recomendado Apple silicon (gerar imagens exige Apple silicon) |
| Windows | 10 ou 11, 64 bits; recomendada placa de vídeo com Vulkan (NVIDIA, AMD ou Intel) |
| Memória | 8 GB de RAM ou mais; 16 GB para os modelos maiores |
| Disco | Cerca de 1–6 GB livres para o motor e o modelo de IA |
| Internet | Para baixar o modelo de IA uma vez e consultar licitações |

## Privacidade

- App desktop: os modelos de IA rodam no seu computador com o llama.cpp (Metal no Mac, Vulkan no Windows). Seus orçamentos, preços e sites ficam no seu computador.
- Versão do navegador: sem IA; seus dados ficam no navegador.
- Uso de rede: baixar o motor e os modelos de IA (GitHub, Hugging Face); o site de compras e o Google, só no navegador do app quando você usa a análise de licitações; "Pesquisar preços" envia seus termos de busca ao Bing.
- Orçamentos e preços são um apoio ao planejamento, não aconselhamento nem uma proposta vinculante.

## Modelos de IA

Os modelos são baixados apenas quando você os escolhe e não fazem parte deste repositório nem dos instaladores. Cada modelo tem sua própria licença.

| Modelo | Tamanho | Licença |
|---|---|---|
| Qwen2.5 0.5B / 1.5B / 7B Instruct | 0,5 / 1,1 / 4,7 GB | Apache-2.0 |
| Llama 3.1 8B Instruct | 4,9 GB | Llama 3.1 Community License (Built with Llama) |
| Stable Diffusion 1.5 / 2.1 / SDXL (imagens) | 1,7–4,8 GB | CreativeML OpenRAIL-M / OpenRAIL++-M |

## Compilar a partir do código

Requer [Flutter](https://flutter.dev) com Dart 3.12 ou posterior; Xcode para compilar no macOS; Visual Studio no Windows para compilar no Windows.

```bash
cd flutter_app
flutter pub get
flutter test                      # testes de unidade e de widgets
flutter run -d macos              # app desktop com IA local
flutter build macos --release     # Pricing AI.app
flutter build web --base-href /app/
```

Teste de integração do app real no Mac (site de compras real e IA local):

```bash
cd flutter_app
LIVE_ENGINE_STORAGE=/path/to/pricing-ai caffeinate -d -i flutter test integration_test/case_analysis_app_test.dart -d macos
```

Site e ferramentas:

| Comando | O que faz |
|---|---|
| `tool/deploy.sh` | Verifica, testa, compila o app web em `/app/`, monta o site e publica no Firebase Hosting (`--no-deploy` só compila) |
| `tool/build_site.sh` | Monta `build/site`: página inicial em `/`, app web em `/app/` |
| `python3 tool/gen_landing.py` | Gera a página inicial focada no download em 5 idiomas (links dos instaladores em `HOSTED_URLS`) |
| `python3 tool/gen_notices.py` | Gera de novo os avisos e textos de licença de terceiros |
| `python3 tool/check_i18n.py` | Verifica se os 5 idiomas têm os mesmos textos |

## Estrutura do repositório

| Pasta | O que é |
|---|---|
| `flutter_app/lib/` | Código do app: `service_pricing/`, `site/` (criar site), `estimator.dart` (orçamento de projeto), `case_analysis/` (análise de licitações), `engine/` (motor de IA local), `i18n/` (5 idiomas), `ui/` |
| `flutter_app/assets/editor/` | O editor de sites (GrapesJS) que roda dentro do app |
| `flutter_app/web/` | Arquivos da versão web, pontes de PDF e de IA no navegador, fontes |
| `flutter_app/landing/` | Páginas iniciais geradas |
| `flutter_app/test/`, `integration_test/` | Testes, com páginas salvas do site de compras como dados de teste |
| `flutter_app/macos/`, `windows/` | Projetos desktop |
| `site_builder/` | Uma versão anterior e independente do editor de sites |
| `css/`, `js/`, `index.html`, `logo/` | A página de orçamento estática original |

## Licença

O Pricing AI é licenciado sob a [Apache License 2.0](LICENSE). Ele usa software de terceiros sob suas próprias licenças, listadas em [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), com os textos completos em [THIRD_PARTY_LICENSES.txt](THIRD_PARTY_LICENSES.txt). Todas as bibliotecas incluídas usam licenças BSD, MIT ou Apache, e as fontes usam a SIL Open Font License.
