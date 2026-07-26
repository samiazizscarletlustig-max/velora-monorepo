import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

const INSIGHT_GENERATION_PROMPT = `You are a top-tier retail and pricing analyst AI. Analyze the following recently updated competitor product data and provide actionable business insights.

Product Data:
{product_data}

Return a valid JSON array of insight objects. Each object MUST strictly have the following keys:
- "title": A short, punchy title for the insight.
- "summary": A detailed explanation of what changed and what it means.
- "ai_recommendation": Actionable advice on how to respond.
- "type": One of ["pricing", "stock", "competitor_strategy", "opportunity"].
- "severity": One of ["low", "medium", "high", "critical"].

Ensure the output is ONLY valid JSON, no markdown formatting like \`\`\`json.`;

const geminiApiKey = Deno.env.get("GEMINI_API_KEY") || "";
const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const supabase = createClient(supabaseUrl, supabaseServiceKey);

serve(async (req: Request) => {
  try {
    if (!geminiApiKey) {
      throw new Error("GEMINI_API_KEY is not set.");
    }

    // 1. Fetch Delta (Products updated recently)
    const { data: recentProducts, error: fetchError } = await supabase
      .from("products")
      .select("*, competitors(workspace_id, name)")
      .gte("last_updated_at", new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());

    if (fetchError || !recentProducts || recentProducts.length === 0) {
      return new Response(JSON.stringify({ message: "No delta found. Skipping AI generation." }), { status: 200 });
    }

    // Group products by workspace to generate specific insights per tenant
    const workspaceDeltas: Record<string, any[]> = {};
    for (const prod of recentProducts) {
      const workspaceId = prod.competitors?.workspace_id;
      if (!workspaceId) continue;
      if (!workspaceDeltas[workspaceId]) workspaceDeltas[workspaceId] = [];
      workspaceDeltas[workspaceId].push(prod);
    }

    // 2. Process each workspace delta using Gemini
    for (const [workspaceId, products] of Object.entries(workspaceDeltas)) {
      
      // DELTA ANALYSIS CHECK:
      // Query the database for the most recent insight for this workspace_id.
      const { data: latestInsight } = await supabase
        .from('ai_insights')
        .select('created_at')
        .eq('workspace_id', workspaceId)
        .order('created_at', { ascending: false })
        .limit(1)
        .single();

      let maxUpdatedAt = 0;
      for (const p of products) {
        const ts = new Date(p.last_updated_at || 0).getTime();
        if (ts > maxUpdatedAt) maxUpdatedAt = ts;
      }

      // If the incoming content is identical to the content analyzed previously
      // (meaning no product was updated AFTER the last insight was generated), skip.
      if (latestInsight && new Date(latestInsight.created_at).getTime() >= maxUpdatedAt) {
        console.log(`Skipping workspace ${workspaceId}: No new changes since last insight.`);
        continue;
      }

      const productDataStr = JSON.stringify(
        products.map(p => ({
          title: p.title,
          competitor: p.competitors.name,
          current_price: p.current_price,
          last_updated: p.last_updated_at
        }))
      );

      const prompt = INSIGHT_GENERATION_PROMPT.replace("{product_data}", productDataStr);

      // Call Gemini 2.0 Flash via REST API (No npm packages)
      const generateRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${geminiApiKey}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            responseMimeType: "application/json"
          }
        }),
      });

      if (!generateRes.ok) {
        const err = await generateRes.text();
        console.error("Gemini Generation Error:", err);
        continue;
      }

      const generateData = await generateRes.json();
      const insightsJson = generateData.candidates?.[0]?.content?.parts?.[0]?.text;
      
      if (!insightsJson) continue;

      let insights = [];
      try {
        insights = JSON.parse(insightsJson);
      } catch (e) {
        console.error("Failed to parse JSON:", insightsJson);
        continue;
      }

      // 3. Generate Embeddings (768 dimensions with text-embedding-004)
      for (const insight of insights) {
        const textToEmbed = `${insight.title}. ${insight.summary}. ${insight.ai_recommendation}. Type: ${insight.type}. Severity: ${insight.severity}`;
        
        const embedRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${geminiApiKey}`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model: "models/text-embedding-004",
            content: { parts: [{ text: textToEmbed }] },
            outputDimensionality: 768
          }),
        });

        if (!embedRes.ok) {
          const err = await embedRes.text();
          console.error("Gemini Embedding Error:", err);
          continue;
        }

        const embedData = await embedRes.json();
        const embedding = embedData.embedding?.values;

        if (!embedding) continue;

        // 4. Save Insight and Embeddings to Database using correct schema column names
        await supabase.from("ai_insights").insert({
          workspace_id: workspaceId,
          title: insight.title,
          summary: insight.summary,
          ai_recommendation: insight.ai_recommendation,
          type: insight.type,
          severity: insight.severity,
          embedding: embedding
        });
      }
    }

    return new Response(JSON.stringify({ message: "Insights generation cycle completed." }), { 
      status: 200, 
      headers: { "Content-Type": "application/json" } 
    });

  } catch (error: any) {
    console.error("Function Error:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});