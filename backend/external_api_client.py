import os
import requests
import json
from dotenv import load_dotenv

# Carrega as variáveis de ambiente do arquivo .env
load_dotenv()

class ExternalAPIService:
    """
    Classe que centraliza a comunicação com todas as APIs externas
    utilizadas pelo sistema "Guia Saúde Local".
    """
    def __init__(self):
        # Carrega as chaves de API de forma segura a partir das variáveis de ambiente
        self.google_api_key = os.getenv("GOOGLE_MAPS_API_KEY")
        self.fcm_server_key = os.getenv("FCM_SERVER_KEY")
        self.demas_api_url = os.getenv("DEMAS_API_BASE_URL")
        self.demas_api_key = os.getenv("DEMAS_API_KEY")

    def get_postos_saude_proximos(self, latitude: float, longitude: float, raio_metros: int = 5000):
        """
        Busca postos de saúde próximos usando a API do Google Maps (Places API).
        """
        if not self.google_api_key:
            return {"erro": "Chave da API do Google Maps não configurada."}

        # Endpoint da Places API para busca por proximidade
        url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
        
        params = {
            "location": f"{latitude},{longitude}",
            "radius": raio_metros,
            "type": "hospital", # 'hospital' é um tipo genérico que inclui clínicas e postos
            "keyword": "posto de saude,upa", # Palavras-chave para refinar a busca
            "language": "pt-BR",
            "key": self.google_api_key,
        }
        
        try:
            response = requests.get(url, params=params)
            response.raise_for_status()  # Lança uma exceção para erros HTTP (4xx ou 5xx)
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Erro ao chamar a API do Google Maps: {e}")
            return {"erro": str(e)}

    def get_dados_unidade_demas(self, unidade_id: str):
        """
        Busca dados detalhados de uma unidade de saúde na API DEMAS.
        *** ESTA É UMA SIMULAÇÃO. SUBSTITUA PELA LÓGICA REAL QUANDO TIVER A API. ***
        """
        print(f"\n--- SIMULAÇÃO: Buscando dados para a unidade '{unidade_id}' na API DEMAS ---")
        
        # A lógica real seria:
        # headers = {"Authorization": f"Bearer {self.demas_api_key}"}
        # url = f"{self.demas_api_url}/unidades/{unidade_id}"
        # response = requests.get(url, headers=headers)
        # return response.json()

        # Retornando dados de exemplo:
        mock_data = {
            "id": unidade_id,
            "nome_oficial": "Centro de Saúde Vila Clóris",
            "horario_funcionamento": "Seg-Sex 07:00-19:00",
            "servicos_oferecidos": [
                "Clínica Médica",
                "Pediatria",
                "Vacinação",
                "Saúde Bucal"
            ],
            "fonte": "API DEMAS"
        }
        return mock_data

    def enviar_notificacao_push(self, device_token: str, titulo: str, mensagem: str):
        """
        Envia uma notificação push para um dispositivo específico via Firebase Cloud Messaging (FCM).
        """
        if not self.fcm_server_key:
            return {"erro": "Chave do servidor FCM não configurada."}

        url = "https://fcm.googleapis.com/fcm/send"
        
        headers = {
            "Authorization": f"key={self.fcm_server_key}",
            "Content-Type": "application/json",
        }

        payload = {
            "to": device_token,
            "notification": {
                "title": titulo,
                "body": mensagem,
                "sound": "default"
            },
            "data": {
                "tipo": "alerta_saude"
            }
        }

        try:
            response = requests.post(url, headers=headers, data=json.dumps(payload))
            response.raise_for_status()
            print("Notificação enviada com sucesso!")
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Erro ao enviar notificação via FCM: {e}")
            return {"erro": str(e)}

# --- Exemplo de como usar a classe ---
if __name__ == "__main__":
    # Instancia o serviço que se comunica com as APIs
    api_service = ExternalAPIService()

    # 1. Exemplo: Buscar postos de saúde perto da Praça Sete em Belo Horizonte
    print("--- Testando a API do Google Maps ---")
    # Coordenadas da Praça Sete, BH
    postos = api_service.get_postos_saude_proximos(latitude=-19.9190, longitude=-43.9386)
    if "erro" not in postos:
        print(f"Encontrados {len(postos.get('results', []))} locais próximos.")
        for lugar in postos.get('results', [])[:2]: # Imprime os 2 primeiros
            print(f"- Nome: {lugar['name']}, Endereço: {lugar['vicinity']}")
    else:
        print(postos["erro"])


    # 2. Exemplo: Buscar dados de uma unidade específica (simulação)
    dados_unidade = api_service.get_dados_unidade_demas(unidade_id="12345")
    print(json.dumps(dados_unidade, indent=2, ensure_ascii=False))


    # 3. Exemplo: Enviar uma notificação push
    print("\n--- Testando o envio de Notificação Push (FCM) ---")
    # Este é um token de dispositivo falso. Para testar, você precisaria de um token real de um app.
    token_falso = "f_exemplo_de_um_token_de_dispositivo_gerado_pelo_app_no_celular"
    resultado_notificacao = api_service.enviar_notificacao_push(
        device_token=token_falso,
        titulo="Nova Campanha de Vacinação",
        mensagem="A campanha de vacinação contra a gripe começa na próxima semana. Confira os locais!"
    )
    print(resultado_notificacao)