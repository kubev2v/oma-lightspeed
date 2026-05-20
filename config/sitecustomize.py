# sitecustomize.py - executed automatically on Python startup
# Routes Gemini model names to the correct LiteLLM provider prefix.
#
# Why needed: LiteLLM auto-detects "gemini-2.5-flash" as Vertex AI and
# requires GCP credentials. Adding "gemini/" prefix forces Gemini API routing.
# But llama-stack's Gemini provider only accepts names without prefix.
# This alias map bridges the gap at runtime.
#
# Routing is automatic: if GOOGLE_APPLICATION_CREDENTIALS and VERTEXAI_PROJECT
# are both set, models route through Vertex AI. Otherwise, they route through
# the Gemini API using GEMINI_API_KEY / GOOGLE_API_KEY.

def _configure_litellm():
    try:
        import os
        import litellm

        if os.environ.get("GOOGLE_APPLICATION_CREDENTIALS") and os.environ.get("VERTEXAI_PROJECT"):
            litellm.model_alias_map = {
                'gemini-2.5-flash': 'vertex_ai/gemini-2.5-flash',
                'gemini-2.5-pro': 'vertex_ai/gemini-2.5-pro',
                'gemini-2.0-flash': 'vertex_ai/gemini-2.0-flash',
                'gemini-1.5-flash': 'vertex_ai/gemini-1.5-flash',
                'gemini-1.5-pro': 'vertex_ai/gemini-1.5-pro',
            }
        else:
            litellm.model_alias_map = {
                'gemini-2.5-flash': 'gemini/gemini-2.5-flash',
                'gemini-2.5-pro': 'gemini/gemini-2.5-pro',
                'gemini-2.0-flash': 'gemini/gemini-2.0-flash',
                'gemini-1.5-flash': 'gemini/gemini-1.5-flash',
                'gemini-1.5-pro': 'gemini/gemini-1.5-pro',
            }
    except ImportError:
        pass

_configure_litellm()
