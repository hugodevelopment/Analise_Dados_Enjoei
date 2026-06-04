// ============================================================
// Cole esse script no Console do Chrome (F12 → Console)
// Ele coleta produtos de múltiplas categorias automaticamente
// e baixa um CSV com todos os dados
// ============================================================

const CATEGORIAS = [
  { cat: 'feminino-roupas',    dep: 'feminino'   },
  { cat: 'masculino-roupas',   dep: 'masculino'  },
  { cat: 'feminino-calcados',  dep: 'feminino'   },
  { cat: 'masculino-calcados', dep: 'masculino'  },
  { cat: 'infantil-roupas',    dep: 'infantil'   },
];

const HEADERS = {
  'accept': 'application/json, text/plain, */*',
  'origin': 'https://www.enjoei.com.br',
  'referer': 'https://www.enjoei.com.br/',
  'x-recommendation-filters-enabled': 'true',
};

function extrairProduto(node, categoria) {
  const precoOri = node.price?.original || 0;
  const precoAt  = node.price?.current  || 0;
  const desc     = precoOri > 0 ? ((precoOri - precoAt) / precoOri * 100).toFixed(1) : 0;
  const tag      = node.tags?.[0]?.text || '';
  return {
    id:             node.id,
    titulo:         node.title?.name || '',
    marca:          node.brand?.displayable_name || 'sem marca',
    preco_original: precoOri,
    preco_atual:    precoAt,
    desconto_pct:   parseFloat(desc),
    tem_desconto:   precoAt < precoOri,
    tamanho:        node.size?.name || '',
    frete_gratis:   node.shipping?.free || false,
    usado:          node.used ?? true,
    vendedor:       node.store?.displayable?.name || '',
    loja:           node.store?.path || '',
    subcategoria:   node.categories?.sub_category?.slug || '',
    categoria:      categoria,
    tag:            tag,
  };
}

function csvLine(obj) {
  return Object.values(obj).map(v =>
    typeof v === 'string' ? `"${v.replace(/"/g,'')}"` : v
  ).join(';');
}

async function coletar() {
  const todos = [];
  const bid = `enjoei-collector-${Date.now()}`;
  const sid = `sid-${Date.now()}`;

  for (const { cat, dep } of CATEGORIAS) {
    console.log(`Coletando: ${cat}...`);
    for (let p = 0; p < 3; p++) {
      const params = new URLSearchParams({
        browser_id: bid,
        city: 'rio-de-janeiro',
        experienced_seller: 'true',
        first: '48',
        operation_name: 'searchProducts',
        'recommendation_context.recommendation_category': cat,
        'recommendation_context.recommendation_department': dep,
        search_context: 'search_categories_menu',
        search_id: sid,
        shipping_range: 'near_regions',
        state: 'rj',
        term: '',
      });

      try {
        const r = await fetch(
          `https://enjusearch.enjoei.com.br/graphql-search-x?${params}`,
          { headers: HEADERS }
        );
        const data = await r.json();
        const edges = data?.data?.search?.products?.edges || [];
        edges.forEach(e => todos.push(extrairProduto(e.node, cat)));
        console.log(`  Página ${p+1}: ${edges.length} produtos`);
        await new Promise(r => setTimeout(r, 1200));
      } catch(e) {
        console.error(`Erro: ${e.message}`);
        break;
      }
    }
  }

  // Gera e baixa o CSV
  const cabecalho = Object.keys(todos[0]).join(';');
  const linhas    = todos.map(csvLine).join('\n');
  const csv       = cabecalho + '\n' + linhas;

  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const url  = URL.createObjectURL(blob);
  const a    = document.createElement('a');
  a.href     = url;
  a.download = 'enjoei_produtos.csv';
  a.click();

  console.log(`\n✅ Coleta concluída! ${todos.length} produtos salvos.`);
  return todos.length;
}

coletar();
