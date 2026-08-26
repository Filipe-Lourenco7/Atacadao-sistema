// Edge Function: create-user
// Chamada pelo app quando o master cadastra um novo usuário de loja.
// Só o master pode chamar isso com sucesso — verificamos o perfil de
// quem está chamando antes de criar qualquer coisa.
//
// Deploy: supabase functions deploy create-user
// (não precisa configurar SUPABASE_SERVICE_ROLE_KEY manualmente —
//  o Supabase já injeta essa variável automaticamente em toda Edge Function)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    const authHeader = req.headers.get('Authorization') ?? '';
    const jwt = authHeader.replace('Bearer ', '');
    if (!jwt) {
      return json({ error: 'Não autenticado.' }, 401);
    }

    // cliente "como o chamador", só pra confirmar quem é e o perfil dele
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    const { data: { user: caller }, error: callerErr } = await callerClient.auth.getUser();
    if (callerErr || !caller) {
      return json({ error: 'Sessão inválida.' }, 401);
    }
    const { data: callerProfile } = await callerClient
      .from('usuarios').select('perfil').eq('id', caller.id).single();
    if (!callerProfile || callerProfile.perfil !== 'master') {
      return json({ error: 'Apenas o administrador (master) pode criar usuários.' }, 403);
    }

    const body = await req.json();
    const { nome, email, senha, perfil, loja_id } = body || {};
    if (!nome || !email || !senha || !perfil) {
      return json({ error: 'Preencha nome, e-mail, senha e perfil.' }, 400);
    }
    if (perfil === 'loja' && !loja_id) {
      return json({ error: 'Selecione a loja deste usuário.' }, 400);
    }
    if (senha.length < 6) {
      return json({ error: 'A senha precisa ter pelo menos 6 caracteres.' }, 400);
    }

    // cliente admin (chave de serviço) — só existe dentro desta função
    const adminClient = createClient(supabaseUrl, serviceKey);

    const { data: created, error: createErr } = await adminClient.auth.admin.createUser({
      email,
      password: senha,
      email_confirm: true,
    });
    if (createErr) {
      return json({ error: createErr.message }, 400);
    }

    const { data: profile, error: profileErr } = await adminClient
      .from('usuarios')
      .insert({
        id: created.user.id,
        nome,
        email,
        perfil,
        loja_id: perfil === 'master' ? null : loja_id,
      })
      .select()
      .single();

    if (profileErr) {
      await adminClient.auth.admin.deleteUser(created.user.id);
      return json({ error: profileErr.message }, 400);
    }

    return json({ ok: true, profile });
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : 'Erro inesperado.' }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
