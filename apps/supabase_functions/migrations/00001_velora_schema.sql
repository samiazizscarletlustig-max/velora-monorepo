-- ==========================================
-- VELORA DATABASE SCHEMA (PHASE 1 - STRICT BLUEPRINT COMPLIANCE)
-- ==========================================

-- Enable pgvector for AI embeddings (VECTOR 1536 as per Blueprint)
CREATE EXTENSION IF NOT EXISTS vector;

-- 1. WORKSPACES TABLE (Multi-tenant foundation)
CREATE TABLE public.workspaces (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  subscription_status TEXT DEFAULT 'free', -- Lemon Squeezy integration
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. USERS TABLE (Linked to Supabase Auth & Workspaces)
CREATE TABLE public.users (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  workspace_id UUID REFERENCES public.workspaces(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'owner',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. COMPETITORS TABLE
CREATE TABLE public.competitors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID REFERENCES public.workspaces(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  website_url TEXT NOT NULL,
  scraping_strategy TEXT DEFAULT 'products.json', 
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. PRODUCTS TABLE (Delta Analysis Foundation)
CREATE TABLE public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  competitor_id UUID REFERENCES public.competitors(id) ON DELETE CASCADE,
  product_url TEXT NOT NULL,
  title TEXT NOT NULL,
  current_price NUMERIC,
  image_url TEXT,
  last_updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(competitor_id, product_url)
);

-- 5. PRICE HISTORY TABLE (Historical tracking)
CREATE TABLE public.price_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  price NUMERIC NOT NULL,
  recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. AI INSIGHTS TABLE (Populated asynchronously)
CREATE TABLE public.ai_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID REFERENCES public.workspaces(id) ON DELETE CASCADE,
  insight_title TEXT NOT NULL,
  insight_details TEXT NOT NULL,
  actionable_advice TEXT,
  embedding VECTOR(1536), -- Strict Blueprint Compliance (1536 dimensions)
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. ALERTS LOG TABLE (System monitoring & notifications)
CREATE TABLE public.alerts_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID REFERENCES public.workspaces(id) ON DELETE CASCADE,
  alert_type TEXT NOT NULL,
  message TEXT NOT NULL,
  status TEXT DEFAULT 'unread',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- ROW LEVEL SECURITY (RLS)
-- ==========================================
ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.competitors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alerts_log ENABLE ROW LEVEL SECURITY;

-- Security Policies (Tenants access ONLY their own workspace data)
CREATE POLICY "Users can view own workspace" ON public.workspaces FOR SELECT USING (id IN (SELECT workspace_id FROM public.users WHERE id = auth.uid()));
CREATE POLICY "Users can view own profile" ON public.users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can manage workspace competitors" ON public.competitors FOR ALL USING (workspace_id IN (SELECT workspace_id FROM public.users WHERE id = auth.uid()));
CREATE POLICY "Users can view workspace products" ON public.products FOR SELECT USING (competitor_id IN (SELECT id FROM public.competitors WHERE workspace_id IN (SELECT workspace_id FROM public.users WHERE id = auth.uid())));
CREATE POLICY "Users can view workspace ai insights" ON public.ai_insights FOR SELECT USING (workspace_id IN (SELECT workspace_id FROM public.users WHERE id = auth.uid()));
CREATE POLICY "Users can view workspace alerts" ON public.alerts_log FOR SELECT USING (workspace_id IN (SELECT workspace_id FROM public.users WHERE id = auth.uid()));
CREATE POLICY "Users can view workspace price history" ON public.price_history FOR SELECT USING (product_id IN (SELECT id FROM public.products WHERE competitor_id IN (SELECT id FROM public.competitors WHERE workspace_id IN (SELECT workspace_id FROM public.users WHERE id = auth.uid()))));
