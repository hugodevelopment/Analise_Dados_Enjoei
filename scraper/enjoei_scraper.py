"""
scraper/enjoei_scraper.py
--------------------------
Coleta dados reais do Enjoei via API GraphQL interna.
Coleta múltiplas categorias e salva em CSV.
"""

import requests
import numpy as np
import pandas as pd
import time
import uuid
from datetime import datetime

# ── Configuração ──────────────────────────────────────────────────────────────
BASE_URL = "https://enjusearch.enjoei.com.br/graphql-search-x"

CATEGORIAS = {
    "feminino-roupas":    "feminino",
    "feminino-calcados":  "feminino",
    "masculino-roupas":   "masculino",
    "masculino-calcados": "masculino",
    "infantil-roupas":    "infantil",
}

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Accept": "application/json",
    "Referer": "https://www.enjoei.com.br/",
}


def gerar_params(categoria: str, departamento: str, pagina: int = 0) -> dict:
    """Gera parâmetros da requisição para uma categoria."""
    browser_id = f"{uuid.uuid4()}-{int(datetime.now().timestamp() * 1000)}"
    search_id  = f"{uuid.uuid4()}-{int(datetime.now().timestamp() * 1000)}"

    return {
        "browser_id":                                   browser_id,
        "city":                                         "rio-de-janeiro",
        "experienced_seller":                           "true",
        "first":                                        "48",
        "operation_name":                               "searchProducts",
        "recommendation_context.recommendation_category": categoria,
        "recommendation_context.recommendation_department": departamento,
        "search_context":                               "search_categories_menu",
        "search_id":                                    search_id,
        "shipping_range":                               "near_regions",
        "state":                                        "rj",
        "term":                                         "",
        "after":                                        str(pagina * 48) if pagina > 0 else "",
    }


def extrair_produto(node: dict, categoria: str) -> dict:
    """Extrai campos relevantes de um produto."""
    preco_original = node.get("price", {}).get("original", 0)
    preco_atual    = node.get("price", {}).get("current", 0)
    desconto_pct   = round((preco_original - preco_atual) / preco_original * 100, 1) if preco_original > 0 else 0

    # Extrai tag de desconto se existir
    tags = node.get("tags", [])
    tag_desconto = tags[0].get("text", "") if tags else ""

    return {
        "id":            node.get("id"),
        "titulo":        node.get("title", {}).get("name", ""),
        "marca":         node.get("brand", {}).get("displayable_name", "sem marca"),
        "preco_original": preco_original,
        "preco_atual":   preco_atual,
        "desconto_pct":  desconto_pct,
        "tem_desconto":  preco_atual < preco_original,
        "tamanho":       node.get("size", {}).get("name", ""),
        "frete_gratis":  node.get("shipping", {}).get("free", False),
        "usado":         node.get("used", True),
        "vendedor":      node.get("store", {}).get("displayable", {}).get("name", ""),
        "loja_path":     node.get("store", {}).get("path", ""),
        "subcategoria":  node.get("categories", {}).get("sub_category", {}).get("slug", ""),
        "categoria":     categoria,
        "tag":           tag_desconto,
    }


def coletar_categoria(categoria: str, departamento: str, paginas: int = 3) -> list:
    """Coleta produtos de uma categoria em múltiplas páginas."""
    produtos = []

    for pagina in range(paginas):
        try:
            params   = gerar_params(categoria, departamento, pagina)
            response = requests.get(BASE_URL, headers=HEADERS, params=params, timeout=10)

            if response.status_code != 200:
                print(f"  ⚠️ Erro {response.status_code} na página {pagina+1}")
                break

            data  = response.json()
            edges = data.get("data", {}).get("search", {}).get("products", {}).get("edges", [])

            if not edges:
                print(f"  ⚠️ Sem dados na página {pagina+1}")
                break

            for edge in edges:
                node = edge.get("node", {})
                if node:
                    produtos.append(extrair_produto(node, categoria))

            print(f"  ✅ Página {pagina+1}: {len(edges)} produtos coletados")
            time.sleep(1.5)  # respeita o rate limit

        except Exception as e:
            print(f"  ❌ Erro: {e}")
            break

    return produtos


def executar_coleta() -> pd.DataFrame:
    """Coleta dados de todas as categorias."""
    print("─" * 50)
    print("  Enjoei Data Collector")
    print("─" * 50)

    todos_produtos = []

    for categoria, departamento in CATEGORIAS.items():
        print(f"\n📦 Coletando: {categoria}")
        produtos = coletar_categoria(categoria, departamento, paginas=3)
        todos_produtos.extend(produtos)
        print(f"  Total: {len(produtos)} produtos")

    df = pd.DataFrame(todos_produtos)
    df = df.drop_duplicates(subset="id")

    caminho = "data/produtos_enjoei.csv"
    df.to_csv(caminho, index=False, sep=";", encoding="utf-8")

    print(f"\n{'─'*50}")
    print(f"  Coleta concluída!")
    print(f"  Total de produtos: {len(df):,}")
    print(f"  Categorias: {df['categoria'].nunique()}")
    print(f"  Arquivo: {caminho}")
    print(f"{'─'*50}")

    return df


if __name__ == "__main__":
    df = executar_coleta()
    print(df.head())
