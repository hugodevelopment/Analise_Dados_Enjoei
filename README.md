# 🛍️ Enjoei Market Intelligence | Web Scraping + SQL + Data Visualization

> *"Antes de comprar ou vender no Enjoei, você deveria ver esses dados."*

---

## 💭 O Problema

O Enjoei tem mais de 10 mil produtos listados só na categoria de roupas femininas. Compradores não sabem se estão pagando justo. Vendedores não sabem como precificar para competir.

Este projeto responde:
> **"Quais categorias têm mais valor? Quais marcas oferecem os maiores descontos? Quais produtos são as melhores oportunidades de compra agora?"**

---

## 🔧 Como os dados foram coletados

A maioria dos projetos de marketplace usa datasets genéricos do Kaggle. Este projeto coleta **dados reais e atuais** diretamente do Enjoei via engenharia reversa da API interna.

```
Inspeção do DevTools (Network)
        ↓
Identificação do endpoint GraphQL interno
        ↓
Requisição autenticada via browser session
        ↓
JSON estruturado com produtos reais
        ↓
Pipeline ETL → CSV → SQLite
```

Essa abordagem garante dados frescos — não um snapshot de 2 anos atrás.

---

## 🏗️ Arquitetura do Projeto

```
enjoei-market-intelligence/
├── scraper/
│   └── enjoei_scraper.py      ← coleta via API GraphQL interna
├── coletor_browser.js         ← script para coleta em massa no browser
├── data/
│   ├── produtos_enjoei.csv    ← dados brutos coletados
│   └── enjoei.db              ← banco SQLite para análise SQL
├── sql/
│   └── analises_enjoei.sql    ← queries de negócio avançadas
├── analysis/
│   └── visualizacoes.py       ← gráficos e insights visuais
└── README.md
```

---

## 📊 Análises SQL Desenvolvidas

### 1. Visão geral do marketplace
Perfil completo da oferta — ticket médio, distribuição de descontos, proporção novo vs usado.

```sql
-- ── 1. VISÃO GERAL DO MARKETPLACE ─────────────────────────────────────────────
-- Pergunta: Qual o perfil geral dos produtos listados?
SELECT
    COUNT(*)                                    AS total_produtos,
    ROUND(AVG(preco_atual), 2)                  AS ticket_medio,
    ROUND(MIN(preco_atual), 2)                  AS menor_preco,
    ROUND(MAX(preco_atual), 2)                  AS maior_preco,
    SUM(CASE WHEN tem_desconto = 1 THEN 1 END)  AS com_desconto,
    ROUND(AVG(CASE WHEN tem_desconto = 1
        THEN desconto_pct END), 2)              AS desconto_medio_pct,
    SUM(CASE WHEN usado = 1 THEN 1 END)         AS produtos_usados,
    SUM(CASE WHEN frete_gratis = 1 THEN 1 END)  AS frete_gratis
FROM produtos;
```

### 2. Performance por subcategoria
Identificação de quais categorias concentram mais valor e mais oferta.

```sql
SELECT
    subcategoria,
    COUNT(*)                   AS qtd_produtos,
    ROUND(AVG(preco_atual), 2) AS ticket_medio,
    ROUND(MAX(preco_atual), 2) AS preco_max
FROM produtos
GROUP BY subcategoria
ORDER BY ticket_medio DESC
```

### 3. Ranking por categoria — Window Function
Produto mais caro de cada categoria usando `ROW_NUMBER() OVER (PARTITION BY)`.

```sql
WITH ranking AS (
    SELECT
        subcategoria, titulo, marca, preco_atual,
        ROW_NUMBER() OVER (
            PARTITION BY subcategoria
            ORDER BY preco_atual DESC
        ) AS rank_preco
    FROM produtos
)
SELECT * FROM ranking WHERE rank_preco = 1
```

### 4. Produtos abaixo da média — Subquery correlacionada
Identifica oportunidades de compra comparando cada produto com a média da sua própria categoria.

```sql
SELECT titulo, marca, preco_atual,
       ROUND(media_categoria, 2) AS media_categoria,
       ROUND(preco_atual - media_categoria, 2) AS diferenca
FROM (
    SELECT *, AVG(preco_atual)
        OVER (PARTITION BY subcategoria) AS media_categoria
    FROM produtos
) t
ORDER BY diferenca ASC
```

### 5. Score de atratividade — CTE
Score composto que combina desconto, preço acessível e condição do produto para ranquear as melhores oportunidades.

```sql
WITH score AS (
    SELECT titulo, marca, preco_atual, desconto_pct,
        ROUND(
            (desconto_pct * 0.6)
            + (CASE WHEN preco_atual < 100 THEN 30 ELSE 10 END)
            + (CASE WHEN usado = 0 THEN 10 ELSE 0 END)
        , 1) AS score_atratividade
    FROM produtos
    WHERE tem_desconto = 1
)
SELECT * FROM score ORDER BY score_atratividade DESC
```

---

## 💡 Insights que os dados revelaram

**Roupas masculinas têm maior ticket médio em valor**

Ticket médio de R$455,09 para roupas masculinas — 1,67x maior que o ticket médio de R$:272. Roupas infantis possuem ticket médio bem abaixo da média com R$ 67

**43% dos produtos têm desconto**

Mercado de segunda mão ainda usa desconto como principal alavanca de conversão.

**Mimus Duda e Adidas lideram em desconto**

Marcas mid-tier praticam descontos acima do desconto média de 18% para girar estoque — oportunidade clara para compradores.

**Produtos novos custam um pouco a mais em relação a usados**

Gap menor do que o esperado, sinalizando que vendedores de itens novos precificam de forma competitiva.

**Produtos populares possuem maior amostragem**

Produtos com a classificam popular possuem 408 produtos do total com ticket médio de R$87.

---




https://github.com/user-attachments/assets/c5f52295-696f-4124-96ba-58ea34c74aef







## 📈 Visualizações

Dashboard interativo com 5 gráficos:
- Ticket médio por categoria
- Distribuição de produtos com desconto (donut)
- Marcas com maior desconto (horizontal bar)
- Novo vs Usado — comparativo de ticket

---


---

## 🛠️ Stack Técnica

- Python — requests, Pandas, Matplotlib, Seaborn
- SQL — SQLite, window functions, CTEs, subqueries correlacionadas
- JavaScript — coleta via API GraphQL interna do Enjoei
- Chart.js — visualizações interativas

---

## 📌 Autor

**Hugo Alves da Costa**
Graduando em Física — UERJ | Analista de Dados

[LinkedIn](https://www.linkedin.com/in/hugo-costa22) • [GitHub](https://github.com/hugodevelopment)
