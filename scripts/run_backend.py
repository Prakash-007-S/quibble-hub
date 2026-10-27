import os
import sys
import uvicorn
from pathlib import Path

# Set backend root
BACKEND_DIR = Path(__file__).resolve().parent.parent / "backend"
sys.path.insert(0, str(BACKEND_DIR))

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    host = os.environ.get("HOST", "0.0.0.0")
    print(f"[*] Starting FastAPI backend on http://localhost:{port}")
    print(f"[*] Swagger UI available at http://localhost:{port}/docs")
    print(f"[*] OpenAPI specification available at http://localhost:{port}/api/v1/openapi.json")
    uvicorn.run("app.main:app", host=host, port=port, reload=False)
