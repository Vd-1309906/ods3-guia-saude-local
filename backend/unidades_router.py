from fastapi import APIRouter, HTTPException, Query
import requests
from .external_api_client import ExternalAPIService # Importa a classe

router = APIRouter()
api_client = ExternalAPIService() # Cria uma instância

@router.get("/demas")
def buscar_unidades_demas_por_localizacao(
    lat: float,
    lon: float,
    force_codigo_municipio: str | None = Query(None, description="Forçar código do município (apenas para testes)."),
):
    """
    Busca estabelecimentos DEMAS/CNES filtrando pelo código do município.

    Comportamento:
    - Se `force_codigo_municipio` for fornecido, será usado (apenas para testes).
    - Caso contrário, tenta detectar o município a partir de (lat, lon) via
      ExternalAPIService.get_municipio_info_por_coordenadas.
    """
    codigo_municipio = None

    # 1) Prioriza valor forçado quando fornecido (útil para testes)
    if force_codigo_municipio:
        codigo_municipio = force_codigo_municipio
        print(f"--- ATENÇÃO: USANDO CÓDIGO DO MUNICÍPIO FORÇADO (TESTE): {codigo_municipio} ---")
    else:
        # 2) Tenta detectar via geocoding/IBGE
        try:
            # Esta chamada já retorna {"codigo_municipio": "311860", ...}
            resultado_ibge = api_client.get_municipio_info_por_coordenadas(latitude=lat, longitude=lon)
            codigo_municipio = resultado_ibge.get("codigo_municipio")
        
        except HTTPException as e:
            # Propaga diretamente a exceção HTTP do serviço (ex: 404, 504)
            raise e
        except Exception as e:
            print(f"Erro inesperado ao detectar município: {e}")
            raise HTTPException(status_code=500, detail=f"Erro interno ao detectar município: {e}")

    if not codigo_municipio:
        raise HTTPException(status_code=400, detail="Código do município não determinado.")

    # Passo 3: Usar o código do município para buscar na API DEMAS/CNES
    try:
        estabelecimentos = api_client.get_estabelecimentos_por_municipio(codigo_municipio)
        return estabelecimentos
    
    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"Erro inesperado ao buscar estabelecimentos: {e}")
        raise HTTPException(status_code=500, detail=f"Erro interno ao buscar estabelecimentos: {e}")


#
# --- ROTA CORRIGIDA ---
#
@router.get("/codes-by-coords")
def obter_codigos_por_coordenadas(lat: float, lon: float):
    """
    Retorna o código do município (IBGE), o código da UF e a sigla da UF
    a partir de coordenadas geográficas.
    """
    try:
        # Esta função JÁ FAZ TODO O TRABALHO:
        # 1. Converte (lat,lon) -> (nome_municipio, sigla_uf) via OSM
        # 2. Converte (nome_municipio, sigla_uf) -> (todos os códigos) via IBGE
        dados_completos = api_client.get_municipio_info_por_coordenadas(latitude=lat, longitude=lon)
        
        # Apenas retorna o JSON completo que o serviço já preparou.
        # Ex: {"codigo_uf": 31, "sigla_uf": "MG", "codigo_municipio": "311860", "nome_municipio": "Ribeirão das Neves"}
        return dados_completos
    
    except HTTPException as e:
        # Se o serviço (OSM ou IBGE) falhar, repassa o erro HTTP
        raise e
    except Exception as e:
        # Pega qualquer outro erro inesperado
        print(f"Erro inesperado em /unidades/codes-by-coords: {e}")
        raise HTTPException(status_code=500, detail=f"Erro interno ao processar coordenadas: {e}")