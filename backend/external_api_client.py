import os
import requests
import json
from dotenv import load_dotenv
import re
from fastapi import HTTPException # <-- ADICIONE ESTA IMPORTAÇÃO

# Carrega as variáveis de ambiente do arquivo .env
load_dotenv()

class ExternalAPIService:
    """
    Classe que centraliza a comunicação com todas as APIs externas
    utilizadas pelo sistema "Guia Saúde Local".
    """
    def __init__(self):
        self.google_api_key = os.getenv("GOOGLE_MAPS_API_KEY")
        self.fcm_server_key = os.getenv("FCM_SERVER_KEY")

    def get_municipio_info_por_coordenadas(self, latitude: float, longitude: float):
        """
        Passo 1: Usa o Google Geocoding (reverso) para encontrar o NOME do município.
        """
        print(f"--- GOOGLE GEOCODING: Buscando nome do município para {latitude}, {longitude} ---")
        if not self.google_api_key:
            return {"erro": "Chave da API do Google Maps não configurada."}
        
        url = "https://maps.googleapis.com/maps/api/geocode/json"
        params = {
            "latlng": f"{latitude},{longitude}",
            "result_type": "administrative_area_level_2", # Nível de município
            "language": "pt-BR",
            "key": self.google_api_key,
        }
        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            
            if data['status'] == 'OK' and data['results']:
                # Itera pelos componentes de endereço para achar o nome da cidade
                for component in data['results'][0]['address_components']:
                    if 'administrative_area_level_2' in component['types']:
                        nome_municipio = component['long_name']
                        print(f"--- GOOGLE GEOCODING: Município encontrado: {nome_municipio} ---")
                        # Passo 2: Com o nome, busca o código IBGE
                        return self.get_codigo_ibge_por_nome(nome_municipio)
            
            print(f"--- GOOGLE GEOCODING: Erro - {data.get('status')} ---")
            return {"erro": "Não foi possível encontrar o município para as coordenadas."}
        
        except requests.exceptions.RequestException as e:
            print(f"Erro ao chamar a API do Google Geocoding: {e}")
            return {"erro": str(e)}

    def get_codigo_ibge_por_nome(self, nome_municipio: str):
        """
        Passo 2: Usa a API pública do IBGE para encontrar o código do município pelo nome.
        """
        print(f"--- API IBGE: Buscando código IBGE para '{nome_municipio}' ---")
        try:
            # Remove acentos e formata para a URL
            nome_normalizado = re.sub(r'[\u0300-\u036f]', '', nome_municipio).lower()
            url = f"https://servicodados.ibge.gov.br/api/v1/localidades/municipios/{nome_normalizado}"
            
            response = requests.get(url)
            response.raise_for_status()
            data = response.json()
            
            # A API do IBGE retorna um objeto ou uma lista
            if isinstance(data, list):
                if data:
                    codigo_ibge = str(data[0]['id'])[:6] # Pega os 6 primeiros dígitos (código do município)
                    print(f"--- API IBGE: Código encontrado (de lista): {codigo_ibge} ---")
                    return {"codigo_ibge": codigo_ibge}
                else:
                    return {"erro": "Município não encontrado na API do IBGE (lista)."}
            elif isinstance(data, dict):
                codigo_ibge = str(data['id'])[:6]
                print(f"--- API IBGE: Código encontrado (de dict): {codigo_ibge} ---")
                return {"codigo_ibge": codigo_ibge}
                
        except requests.exceptions.RequestException as e:
            print(f"Erro ao chamar a API do IBGE: {e}")
            return {"erro": str(e)}

    def get_estabelecimentos_por_municipio(self, codigo_municipio: str):
        """
        Passo 3: Usa a API DEMAS (real) que você encontrou, filtrando pelo código do município.
        """
        url = "https://apidadosabertos.saude.gov.br/cnes/estabelecimentos"
        params = {
            "codigo_municipio": codigo_municipio
        }
        
        print(f"--- API DEMAS: Buscando estabelecimentos para o município {codigo_municipio} (timeout=15s) ---")
        
        try:
            # --- MUDANÇA AQUI: Adicionado um timeout de 15 segundos ---
            response = requests.get(url, params=params, timeout=15)
            
            response.raise_for_status() # Lança erro para status 4xx/5xx
            data = response.json()
            
            estabelecimentos_formatados = []
            if 'estabelecimentos' not in data:
                 print(f"--- API DEMAS: Resposta OK, mas sem a chave 'estabelecimentos'. Total: 0 ---")
                 return []

            for item in data.get('estabelecimentos', []):
                lat_str = item.get('nu_latitude')
                lon_str = item.get('nu_longitude')

                # Filtro robusto (o que fizemos antes, está correto)
                if (lat_str and lon_str and
                    lat_str != "null" and lon_str != "null" and
                    lat_str != "0.0" and lon_str != "0.0"):
                    
                    try:
                        estabelecimentos_formatados.append({
                            "id": item.get('co_unidade'),
                            "nome": item.get('nome_razao_social'),
                            "endereco": f"{item.get('endereco_estabelecimento', '')}, {item.get('numero_estabelecimento', '')} - {item.get('bairro_estabelecimento', '')}",
                            "latitude": float(lat_str),
                            "longitude": float(lon_str)
                        })
                    except (ValueError, TypeError):
                        print(f"--- API DEMAS: Ignorando posto {item.get('co_unidade')} por dado de GPS inválido ---")
                        pass 

            print(f"--- API DEMAS: Encontrados {len(estabelecimentos_formatados)} estabelecimentos com lat/lon válidas. ---")
            return estabelecimentos_formatados

        # --- MUDANÇA AQUI: Captura *qualquer* exceção (Timeout, Conexão, JSON, etc.) ---
        except Exception as e:
            print(f"!!!!!!!! ERRO GERAL AO CHAMAR API DEMAS !!!!!!!!")
            print(f"Erro: {e}")
            # Retorna um erro que o FastAPI pode enviar ao app, em vez de crachar
            # Usar 'raise' aqui é melhor para o FastAPI lidar com o erro corretamente
            raise HTTPException(status_code=504, detail=f"Falha ao buscar dados do DEMAS: {e}")
        
def enviar_notificacao_push(self, device_token: str, titulo: str, mensagem: str):
    """
    Envia uma notificação push para um dispositivo específico via Firebase Cloud Messaging (FCM).
    """
    print(f"--- FCM: Tentando enviar notificação para o token: {device_token[:10]}... ---")

    if not self.fcm_server_key:
        print("--- FCM ERRO: Chave do servidor FCM não configurada no .env ---")
        return {"erro": "Chave do servidor FCM não configurada."}

    url = "https://fcm.googleapis.com/fcm/send"

    # Cabeçalho de autorização com a chave que pegamos no Passo 1
    headers = {
        "Authorization": f"key={self.fcm_server_key}",
        "Content-Type": "application/json",
    }

    # O "corpo" da notificação que o celular vai receber
    payload = {
        "to": device_token, # O token específico do celular
        "notification": {
            "title": titulo,
            "body": mensagem,
            "sound": "default"
        },
        "data": {
            "tipo": "alerta_saude",
            "id_campanha": "1234"
        }
    }

    try:
        response = requests.post(url, headers=headers, data=json.dumps(payload), timeout=10)
        response.raise_for_status()
        print("--- FCM: Notificação enviada com sucesso! ---")
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"--- FCM ERRO: Erro ao enviar notificação: {e} ---")
        print(f"--- FCM Resposta: {e.response.text if e.response else 'Sem resposta'} ---")
        return {"erro": str(e)}