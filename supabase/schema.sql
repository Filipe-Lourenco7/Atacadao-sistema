-- ============================================================
-- Atacadão Pet — schema Supabase
-- Rode este script inteiro no painel do Supabase:
-- SQL Editor > New query > colar tudo > Run
-- ============================================================
create extension if not exists pgcrypto;

-- ---------- LOJAS ----------
create table lojas (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

-- ---------- USUÁRIOS (perfil ligado ao auth.users do Supabase) ----------
create table usuarios (
  id uuid primary key references auth.users(id) on delete cascade,
  nome text not null,
  email text not null,
  perfil text not null check (perfil in ('master','loja')),
  loja_id uuid references lojas(id),
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  constraint loja_obrigatoria_se_operador check (
    (perfil = 'loja' and loja_id is not null) or (perfil = 'master')
  )
);

-- ---------- FORMAS DE PAGAMENTO / CATEGORIAS (globais, toda a rede) ----------
create table formas_pagamento (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  taxa_percentual numeric not null default 0,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

create table categorias (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  tipo text not null check (tipo in ('despesa','receita')),
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

-- ---------- CONFIG (linha única, dados gerais da rede) ----------
create table config (
  id boolean primary key default true check (id),
  nome_negocio text not null default 'Atacadão Pet',
  imposto numeric not null default 0,
  taxa_credito numeric not null default 3.5,
  taxa_debito numeric not null default 2.0,
  taxa_pix numeric not null default 0
);

-- ---------- FORNECEDORES (compartilhado entre lojas) ----------
create table fornecedores (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  razao_social text,
  documento text,
  whatsapp text,
  nome_vendedor text,
  prazo_pagamento text,
  produtos text,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

-- ---------- PRODUTOS / ESTOQUE (por loja) ----------
create table produtos (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references lojas(id),
  nome text not null,
  categoria text,
  unidade text,
  quantidade_atual numeric not null default 0,
  custo_unitario numeric not null default 0,
  preco_venda numeric not null default 0,
  data_ultima_compra date,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

create table mov_estoque (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references lojas(id),
  produto_id uuid references produtos(id),
  tipo text not null,
  quantidade numeric not null,
  custo_unitario_no_momento numeric,
  referencia_id uuid,
  observacao text,
  usuario_id uuid references usuarios(id),
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

-- ---------- COMPRAS ----------
create table compras (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references lojas(id),
  fornecedor_id uuid references fornecedores(id),
  data_pedido date,
  previsao_entrega date,
  data_recebimento date,
  valor_combinado numeric not null default 0,
  status text not null default 'solicitada',
  itens_qtd integer not null default 0,
  usuario_id uuid references usuarios(id),
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

create table compra_itens (
  id uuid primary key default gen_random_uuid(),
  compra_id uuid not null references compras(id) on delete cascade,
  loja_id uuid not null references lojas(id),
  produto_id uuid references produtos(id),
  quantidade_pedida numeric not null,
  custo_unitario_combinado numeric not null,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

-- ---------- VENDAS ----------
create table vendas (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references lojas(id),
  tipo text not null default 'individual',
  data date not null,
  forma_pagamento_id uuid references formas_pagamento(id),
  desconto numeric not null default 0,
  valor_total numeric not null default 0,
  observacao text,
  status text not null default 'registrada',
  cancelado boolean not null default false,
  usuario_id uuid references usuarios(id),
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

create table venda_itens (
  id uuid primary key default gen_random_uuid(),
  venda_id uuid not null references vendas(id) on delete cascade,
  loja_id uuid not null references lojas(id),
  produto_id uuid references produtos(id),
  nome text,
  quantidade numeric not null,
  valor_unitario numeric not null,
  valor_total numeric not null,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

-- ---------- CAIXA ----------
create table caixas (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references lojas(id),
  tipo text not null default 'diario',
  data_abertura date,
  data_fechamento date,
  saldo_inicial numeric not null default 0,
  valor_esperado numeric,
  valor_informado numeric,
  diferenca numeric,
  status text not null default 'aberto',
  usuario_abertura_id uuid references usuarios(id),
  usuario_fechamento_id uuid references usuarios(id),
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

create table mov_caixa (
  id uuid primary key default gen_random_uuid(),
  caixa_id uuid not null references caixas(id) on delete cascade,
  loja_id uuid not null references lojas(id),
  tipo text not null,
  valor numeric not null,
  descricao text,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

-- ---------- FINANCEIRO ----------
create table despesas (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references lojas(id),
  descricao text not null,
  tipo text not null,
  categoria_id uuid references categorias(id),
  valor numeric not null,
  data_competencia date,
  data_vencimento date,
  data_pagamento date,
  recorrencia text,
  status text not null default 'pendente',
  compra_id uuid references compras(id),
  usuario_id uuid references usuarios(id),
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

create table receitas (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references lojas(id),
  descricao text not null,
  categoria_id uuid references categorias(id),
  valor numeric not null,
  data_competencia date,
  status text not null default 'recebido',
  usuario_id uuid references usuarios(id),
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

-- ---------- ANOTAÇÕES ----------
create table anotacoes (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references lojas(id),
  titulo text not null,
  descricao text,
  categoria text,
  prioridade text,
  status text not null default 'aberta',
  usuario_id uuid references usuarios(id),
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

-- ============================================================
-- FUNÇÕES AUXILIARES (security definer: evitam recursão no RLS)
-- ============================================================
create or replace function is_master()
returns boolean
language sql security definer stable
set search_path = public
as $$
  select exists(
    select 1 from usuarios where id = auth.uid() and perfil = 'master' and ativo
  );
$$;

create or replace function my_loja_id()
returns uuid
language sql security definer stable
set search_path = public
as $$
  select loja_id from usuarios where id = auth.uid();
$$;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table lojas enable row level security;
alter table usuarios enable row level security;
alter table formas_pagamento enable row level security;
alter table categorias enable row level security;
alter table config enable row level security;
alter table fornecedores enable row level security;
alter table produtos enable row level security;
alter table mov_estoque enable row level security;
alter table compras enable row level security;
alter table compra_itens enable row level security;
alter table vendas enable row level security;
alter table venda_itens enable row level security;
alter table caixas enable row level security;
alter table mov_caixa enable row level security;
alter table despesas enable row level security;
alter table receitas enable row level security;
alter table anotacoes enable row level security;

-- LOJAS: leitura geral autenticada; escrita só master
create policy lojas_select on lojas for select to authenticated using (true);
create policy lojas_write on lojas for all to authenticated using (is_master()) with check (is_master());

-- USUÁRIOS: cada um lê o próprio perfil; master lê/gerencia todos
create policy usuarios_select on usuarios for select to authenticated using (id = auth.uid() or is_master());
create policy usuarios_insert on usuarios for insert to authenticated with check (is_master());
create policy usuarios_update on usuarios for update to authenticated using (is_master()) with check (is_master());
create policy usuarios_delete on usuarios for delete to authenticated using (is_master());

-- FORMAS DE PAGAMENTO / CATEGORIAS: leitura geral; escrita só master
create policy fp_select on formas_pagamento for select to authenticated using (true);
create policy fp_write on formas_pagamento for all to authenticated using (is_master()) with check (is_master());
create policy cat_select on categorias for select to authenticated using (true);
create policy cat_write on categorias for all to authenticated using (is_master()) with check (is_master());

-- CONFIG: leitura geral; só master atualiza
create policy config_select on config for select to authenticated using (true);
create policy config_update on config for update to authenticated using (is_master()) with check (is_master());

-- FORNECEDORES: compartilhado — qualquer usuário autenticado lê/gerencia
create policy forn_select on fornecedores for select to authenticated using (true);
create policy forn_write on fornecedores for all to authenticated using (true) with check (true);

-- TABELAS POR LOJA: master vê/edita tudo; operador só a própria loja
create policy produtos_all on produtos for all to authenticated
  using (is_master() or loja_id = my_loja_id()) with check (is_master() or loja_id = my_loja_id());
create policy mov_estoque_all on mov_estoque for all to authenticated
  using (is_master() or loja_id = my_loja_id()) with check (is_master() or loja_id = my_loja_id());
create policy compras_all on compras for all to authenticated
  using (is_master() or loja_id = my_loja_id()) with check (is_master() or loja_id = my_loja_id());
create policy compra_itens_all on compra_itens for all to authenticated
  using (is_master() or loja_id = my_loja_id()) with check (is_master() or loja_id = my_loja_id());
create policy vendas_all on vendas for all to authenticated
  using (is_master() or loja_id = my_loja_id()) with check (is_master() or loja_id = my_loja_id());
create policy venda_itens_all on venda_itens for all to authenticated
  using (is_master() or loja_id = my_loja_id()) with check (is_master() or loja_id = my_loja_id());
create policy caixas_all on caixas for all to authenticated
  using (is_master() or loja_id = my_loja_id()) with check (is_master() or loja_id = my_loja_id());
create policy mov_caixa_all on mov_caixa for all to authenticated
  using (is_master() or loja_id = my_loja_id()) with check (is_master() or loja_id = my_loja_id());
create policy despesas_all on despesas for all to authenticated
  using (is_master() or loja_id = my_loja_id()) with check (is_master() or loja_id = my_loja_id());
create policy receitas_all on receitas for all to authenticated
  using (is_master() or loja_id = my_loja_id()) with check (is_master() or loja_id = my_loja_id());
create policy anotacoes_all on anotacoes for all to authenticated
  using (is_master() or loja_id = my_loja_id()) with check (is_master() or loja_id = my_loja_id());

-- ============================================================
-- DADOS INICIAIS
-- ============================================================
insert into config (id) values (true);

insert into lojas (nome) values ('Loja 1'), ('Loja 2'), ('Loja 3');

insert into formas_pagamento (nome, taxa_percentual) values
  ('Dinheiro', 0), ('Pix', 0), ('Cartão de débito', 2.0), ('Cartão de crédito', 3.5), ('Outros', 0);

insert into categorias (nome, tipo) values
  ('Aluguel','despesa'),('Energia','despesa'),('Água','despesa'),('Salários','despesa'),
  ('Compra de mercadorias','despesa'),('Marketing','despesa'),('Impostos','despesa'),
  ('Manutenção','despesa'),('Outros','despesa'),('Vendas','receita'),('Outras receitas','receita');

-- ============================================================
-- BOOTSTRAP DO USUÁRIO MASTER (fazer manualmente, uma vez):
-- 1. Painel Supabase > Authentication > Users > Add user
--    - marque "Auto Confirm User"
--    - anote o UUID do usuário criado
-- 2. Rode abaixo, substituindo os valores:
--
-- insert into usuarios (id, nome, email, perfil, loja_id)
-- values ('COLE-O-UUID-AQUI', 'Administrador', 'email-que-voce-cadastrou@dominio.com', 'master', null);
-- ============================================================
