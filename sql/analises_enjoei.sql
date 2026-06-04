-- ============================================================
-- ANÁLISE DE DADOS — ENJOEI MARKETPLACE
-- Queries SQL com insights de negócio para a vaga de Analista
-- ============================================================

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


-- ── 2. PERFORMANCE POR SUBCATEGORIA ───────────────────────────────────────────
-- Pergunta: Quais categorias têm mais produtos e maior ticket médio?
-- Insight: identifica onde o marketplace tem mais oferta e valor
SELECT
    REPLACE(REPLACE(subcategoria, 'mocas-roupas-', ''), '-', ' ') AS categoria,
    COUNT(*)                        AS qtd_produtos,
    ROUND(AVG(preco_atual), 2)      AS ticket_medio,
    ROUND(MIN(preco_atual), 2)      AS preco_min,
    ROUND(MAX(preco_atual), 2)      AS preco_max,
    SUM(CASE WHEN tem_desconto = 1
        THEN 1 ELSE 0 END)          AS com_desconto,
    ROUND(AVG(CASE WHEN tem_desconto = 1
        THEN desconto_pct END), 2)  AS desc_medio_pct
FROM produtos
GROUP BY subcategoria
ORDER BY ticket_medio DESC;


-- ── 3. ANÁLISE DE DESCONTO — MARCAS QUE MAIS DESCONTAM ────────────────────────
-- Pergunta: Quais marcas oferecem os maiores descontos?
-- Insight: marcas premium dão mais desconto para girar estoque
SELECT
    marca,
    COUNT(*)                                AS total_listagens,
    SUM(CASE WHEN tem_desconto = 1
        THEN 1 ELSE 0 END)                  AS com_desconto,
    ROUND(AVG(preco_original), 2)           AS preco_medio_original,
    ROUND(AVG(preco_atual), 2)              AS preco_medio_atual,
    ROUND(AVG(CASE WHEN tem_desconto = 1
        THEN desconto_pct END), 2)          AS desconto_medio_pct,
    ROUND(AVG(preco_original)
        - AVG(preco_atual), 2)              AS economia_media
FROM produtos
WHERE marca != 'sem marca'
GROUP BY marca
HAVING COUNT(*) >= 1
ORDER BY desconto_medio_pct DESC NULLS LAST
LIMIT 10;


-- ── 4. WINDOW FUNCTION — RANKING DE PREÇO POR CATEGORIA ───────────────────────
-- Pergunta: Qual o produto mais caro de cada categoria?
-- Técnica: ROW_NUMBER com PARTITION BY para ranking por grupo
WITH ranking AS (
    SELECT
        REPLACE(REPLACE(subcategoria, 'mocas-roupas-', ''), '-', ' ') AS categoria,
        titulo,
        marca,
        preco_atual,
        tamanho,
        ROW_NUMBER() OVER (
            PARTITION BY subcategoria
            ORDER BY preco_atual DESC
        ) AS rank_preco
    FROM produtos
)
SELECT categoria, titulo, marca, preco_atual, tamanho
FROM ranking
WHERE rank_preco = 1
ORDER BY preco_atual DESC;


-- ── 5. ANÁLISE DE OPORTUNIDADE — PRODUTOS ABAIXO DA MÉDIA ────────────────────
-- Pergunta: Quais produtos estão precificados abaixo da média da categoria?
-- Insight: oportunidade de compra ou gap de precificação do vendedor
SELECT
    titulo,
    marca,
    preco_atual,
    ROUND(media_categoria, 2)                               AS media_categoria,
    ROUND(preco_atual - media_categoria, 2)                 AS diferenca,
    ROUND((preco_atual - media_categoria)
          / media_categoria * 100, 1)                       AS pct_vs_media,
    CASE
        WHEN preco_atual < media_categoria * 0.7 THEN 'Muito abaixo'
        WHEN preco_atual < media_categoria       THEN 'Abaixo da média'
        WHEN preco_atual < media_categoria * 1.3 THEN 'Na média'
        ELSE 'Acima da média'
    END                                                     AS posicionamento
FROM (
    SELECT
        titulo, marca, preco_atual, subcategoria,
        AVG(preco_atual) OVER (PARTITION BY subcategoria) AS media_categoria
    FROM produtos
) t
ORDER BY pct_vs_media ASC
LIMIT 10;


-- ── 6. ANÁLISE DE CONDIÇÃO — NOVO vs USADO ────────────────────────────────────
-- Pergunta: Há diferença de preço entre produtos novos e usados?
-- Insight: validar se vendedores precificam corretamente o estado do produto
SELECT
    CASE WHEN usado = 1 THEN 'Usado' ELSE 'Novo' END AS condicao,
    COUNT(*)                                           AS qtd,
    ROUND(AVG(preco_atual), 2)                         AS ticket_medio,
    ROUND(AVG(desconto_pct), 2)                        AS desconto_medio,
    SUM(CASE WHEN tem_desconto = 1 THEN 1 ELSE 0 END)  AS com_desconto
FROM produtos
GROUP BY usado;


-- ── 7. CTE — SCORE DE ATRATIVIDADE DOS PRODUTOS ───────────────────────────────
-- Pergunta: Quais produtos combinam bom preço E desconto elevado?
-- Técnica: CTE para criar score composto de atratividade
WITH score AS (
    SELECT
        titulo,
        marca,
        preco_atual,
        desconto_pct,
        tamanho,
        CASE WHEN tem_desconto = 1 THEN 1 ELSE 0 END   AS bonus_desconto,
        CASE WHEN usado = 0        THEN 1 ELSE 0 END   AS bonus_novo,
        -- Score: desconto alto + preço acessível = mais atrativo
        ROUND(
            (desconto_pct * 0.6)
            + (CASE WHEN preco_atual < 100 THEN 30
                    WHEN preco_atual < 200 THEN 20
                    WHEN preco_atual < 500 THEN 10
                    ELSE 0 END)
            + (CASE WHEN usado = 0 THEN 10 ELSE 0 END)
        , 1) AS score_atratividade
    FROM produtos
    WHERE tem_desconto = 1
)
SELECT
    titulo, marca, preco_atual, desconto_pct, tamanho, score_atratividade
FROM score
ORDER BY score_atratividade DESC
LIMIT 8;
