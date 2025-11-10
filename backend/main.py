import uvicorn
from fastapi import FastAPI, Form, HTTPException
from typing import Annotated 

# Importa o roteador e o cliente
from . import unidades_router
from .external_api_client import ExternalAPIService

# --- NOVO ---
# Cria uma lista simples (em memória) para guardar os tokens
# Nota: Numa app real, isto seria um banco de dados!
dispositivos_registrados = set()
# --- FIM NOVO ---

app = FastAPI(
    title="Guia Saúde Local API",
    description="API para o aplicativo de ODS 3 (Saúde e Bem-Estar)",
    version="1.0.0"
)

# Cria uma instância única do nosso cliente de API
api_client = ExternalAPIService()

# Inclui as rotas de /unidades/...
app.include_router(unidades_router.router, prefix="/unidades", tags=["Unidades"])


@app.get("/", tags=["Root"])
def read_root():
    return {"status": "API está no ar!"}

# --- ROTA ATUALIZADA ---
@app.post("/registrar-dispositivo", tags=["Notificações"])
def registrar_dispositivo(token: Annotated[str, Form()]):
    """
    Recebe um token de dispositivo do app e o guarda na nossa lista.
    """
    print(f"--- TOKEN DE DISPOSITIVO RECEBIDO: {token[:15]}... ---")
    dispositivos_registrados.add(token) # Adiciona o token ao set
    print(f"--- Total de dispositivos registrados: {len(dispositivos_registrados)} ---")
    return {"status": "Token registrado com sucesso"}

# --- ROTA NOVA PARA TESTE ---
@app.post("/enviar-alerta-geral", tags=["Notificações"])
def enviar_alerta_geral(titulo: Annotated[str, Form()], mensagem: Annotated[str, Form()]):
    """
    Envia uma notificação para TODOS os dispositivos registrados.
    Usaremos isto para testar no TP4.
    """
    print(f"--- ENVIANDO ALERTA GERAL PARA {len(dispositivos_registrados)} DISPOSITIVOS ---")
    if not dispositivos_registrados:
        raise HTTPException(status_code=400, detail="Nenhum dispositivo registrado para enviar.")

    sucessos = 0
    falhas = 0

    for token in dispositivos_registrados:
        resultado = api_client.enviar_notificacao_push(
            device_token=token,
            titulo=titulo,
            mensagem=mensagem
        )
        if "erro" not in resultado:
            sucessos += 1
        else:
            falhas += 1

    return {
        "status": "Envio de alertas concluído.",
        "sucessos": sucessos,
        "falhas": falhas
    }

# --- FIM ROTA NOVA ---


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)