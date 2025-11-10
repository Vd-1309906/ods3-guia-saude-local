from fastapi import APIRouter, HTTPException, Query
import requests
from .external_api_client import ExternalAPIService # Importa a classe

router = APIRouter()
api_client = ExternalAPIService() # Cria uma instância

@router.get("/unidades/demas")
def buscar_unidades_demas_por_localizacao(
    lat: float,
    lon: float,
    force_codigo_municipio: str | None = Query(None, description="Forçar código do município (apenas para testes)."),
    force_codigo_uf: int | None = Query(None, description="Forçar código da UF (apenas para testes)."),
):
    """
    Busca estabelecimentos DEMAS filtrando pelo código do município.

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
            resultado_ibge = api_client.get_municipio_info_por_coordenadas(latitude=lat, longitude=lon)
            if "erro" in resultado_ibge:
                print(f"Erro na etapa 1 (Geocoding/IBGE): {resultado_ibge['erro']}")
                raise HTTPException(status_code=404, detail=resultado_ibge["erro"])
            codigo_municipio = resultado_ibge.get("codigo_ibge")
        except HTTPException:
            # Propaga diretamente a exceção HTTP para o cliente
            raise
        except Exception as e:
            print(f"Erro ao detectar município por coordenadas: {e}")
            raise HTTPException(status_code=504, detail=f"Erro ao detectar município: {e}")

    if not codigo_municipio:
        raise HTTPException(status_code=400, detail="Código do município não determinado.")

    # Passo 2: Usar o código do município para buscar na API DEMAS
    estabelecimentos = api_client.get_estabelecimentos_por_municipio(codigo_municipio)

    if "erro" in estabelecimentos:
        print(f"Erro na etapa 2 (DEMAS): {estabelecimentos['erro']}")
        raise HTTPException(status_code=500, detail=estabelecimentos["erro"])

    # Passo 3: Retornar a lista de estabelecimentos para o Flutter
    # O Flutter vai cuidar de calcular a distância e ordenar.
    return estabelecimentos


@router.get("/unidades/codes-by-coords")
def obter_codigos_por_coordenadas(lat: float, lon: float):
    """
    Retorna o código do município (IBGE) e o código da UF a partir
    de coordenadas geográficas. Usa o ExternalAPIService para extrair
    o nome do município via Geocoding e em seguida consulta a API do IBGE
    para obter informações adicionais (UF).
    """
    try:
        resultado_ibge = api_client.get_municipio_info_por_coordenadas(latitude=lat, longitude=lon)
    except HTTPException as e:
        raise e

    codigo_municipio = resultado_ibge.get("codigo_ibge")
    if not codigo_municipio:
        raise HTTPException(status_code=404, detail="Código do município não encontrado para as coordenadas.")

    # Consulta detalhes do município no IBGE para extrair a UF
    try:
        ibge_url = f"https://servicodados.ibge.gov.br/api/v1/localidades/municipios/{codigo_municipio}"
        resp = requests.get(ibge_url, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        # Estrutura: data['microrregiao']['mesorregiao']['UF']
        uf_info = data.get('microrregiao', {}).get('mesorregiao', {}).get('UF', {})
        codigo_uf = uf_info.get('id')
        sigla_uf = uf_info.get('sigla')
    except Exception as e:
        raise HTTPException(status_code=504, detail=f'Erro ao consultar IBGE para obter UF: {e}')

    return {
        "codigo_municipio": codigo_municipio,
        "codigo_uf": codigo_uf,
        "uf_sigla": sigla_uf,
    }

# (Você pode adicionar outros endpoints aqui, como o de campanhas)