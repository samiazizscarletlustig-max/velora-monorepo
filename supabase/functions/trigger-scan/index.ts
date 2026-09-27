import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { user_id } = await req.json()
    
    const githubPat = Deno.env.get('GITHUB_PAT')
    const githubRepo = Deno.env.get('GITHUB_REPO')
    const githubWorkflow = Deno.env.get('GITHUB_WORKFLOW')

    if (!githubPat || !githubRepo || !githubWorkflow) {
      throw new Error('GitHub credentials not configured in Supabase Secrets')
    }

    // Trigger GitHub Actions Workflow Dispatch
    const response = await fetch(
      `https://api.github.com/repos/${githubRepo}/actions/workflows/${githubWorkflow}/dispatches`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${githubPat}`,
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          ref: 'main',
          inputs: {
            user_id: user_id || 'all'
          }
        })
      }
    )

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`GitHub API error: ${response.status} - ${errorText}`)
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Scan triggered successfully! Results will appear in 3-5 minutes.' 
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})