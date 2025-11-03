from fastapi import APIRouter, HTTPException, Query
from .external_api_client import ExternalAPIService # Importa a classe

router = APIRouter()
api_client = ExternalAPIService() # Cria uma instância

@router.get("/unidades/demas")
def buscar_unidades_demas_por_localizacao(lat: float, lon: float):
    
    # Passo 1: Converter (lat, lon) -> código do município
    # resultado_ibge = api_client.get_municipio_info_por_coordenadas(latitude=lat, longitude=lon)

    # if "erro" in resultado_ibge:
    #     print(f"Erro na etapa 1 (Geocoding/IBGE): {resultado_ibge['erro']}")
    #     raise HTTPException(status_code=404, detail=resultado_ibge["erro"])

    # codigo_municipio = resultado_ibge["codigo_ibge"]

    # --- LINHA DE TESTE TEMPORÁRIA ---
    codigo_municipio = "310620" # Forçando Belo Horizonte para termos dados para filtrar
    print(f"--- ATENÇÃO: FORÇANDO CÓDIGO DO MUNICÍPIO (TESTE): {codigo_municipio} ---")
    # --- FIM DA LINHA DE TESTE ---
    # Passo 2: Usar o código do município para buscar na API DEMAS
    estabelecimentos = api_client.get_estabelecimentos_por_municipio(codigo_municipio)
    
    if "erro" in estabelecimentos:
        print(f"Erro na etapa 2 (DEMAS): {estabelecimentos['erro']}")
        raise HTTPException(status_code=500, detail=estabelecimentos["erro"])
    
    # Passo 3: Retornar a lista de estabelecimentos para o Flutter
    # O Flutter vai cuidar de calcular a distância e ordenar.
    return estabelecimentos

# (Você pode adicionar outros endpoints aqui, como o de campanhas)