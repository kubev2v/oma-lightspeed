# sitecustomize.py - executed automatically on Python startup
# Routes Gemini model names to use Gemini API instead of Vertex AI
#
# Why needed: LiteLLM auto-detects "gemini-2.5-flash" as Vertex AI and
# requires GCP credentials. Adding "gemini/" prefix forces Gemini API routing.
# But llama-stack's Gemini provider only accepts names without prefix.
# This alias map bridges the gap at runtime.

def _configure_litellm():
    try:
        import litellm
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
