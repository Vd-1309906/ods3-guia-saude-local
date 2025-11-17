import os
import requests
import json
import unicodedata # <--- Importado para a função de normalizar
import re
from dotenv import load_dotenv
from fastapi import HTTPException

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
        Passo 1: Usa o OpenStreetMap (Nominatim) para encontrar o NOME e o ESTADO.
        """
        print(f"--- OSM/NOMINATIM: Buscando dados para {latitude}, {longitude} ---")
        
        url = "https://nominatim.openstreetmap.org/reverse"
        params = {
            "lat": latitude,
            "lon": longitude,
            "format": "jsonv2",
            "accept-language": "pt-BR",
            "zoom": 10 
        }
        headers = {
            "User-Agent": "AppGuiaSaudeLocal/1.0 (seu.email@exemplo.com)"
        }
        
        try:
            response = requests.get(url, params=params, headers=headers, timeout=10)
            response.raise_for_status()
            data = response.json()
            
            if data and data.get('address'):
                address = data['address']
                
                # --- CORREÇÃO DE PRIORIDADE AQUI ---
                # Prioriza 'city' (cidade) ou 'town' (vila) antes de 'municipality' (região)
                nome_municipio = (address.get('city') or 
                                  address.get('town') or 
                                  address.get('village') or 
                                  address.get('municipality'))
                print(f"--- {nome_municipio} ---")
                iso_uf = address.get('ISO3166-2-lvl4')
                sigla_uf = None
                if iso_uf and iso_uf.startswith('BR-'):
                    sigla_uf = iso_uf.split('-')[-1] # Pega "MG"

                if nome_municipio and sigla_uf:
                    print(f"--- OSM/NOMINATIM: Encontrado: {nome_municipio} - {sigla_uf} ---")
                    # Passo 2: Com o nome, busca os códigos IBGE
                    return self.get_ibge_codes(nome_municipio, sigla_uf)
            
            print(f"--- OSM/NOMINATIM: Erro - Não encontrou Município/UF no JSON ---")
            raise HTTPException(status_code=404, detail="Não foi possível encontrar o município (OSM) para as coordenadas.")
        
        except requests.exceptions.RequestException as e:
            print(f"Erro ao chamar a API do OSM/Nominatim: {e}")
            raise HTTPException(status_code=504, detail=f"Falha ao chamar API de Geocoding (OSM): {e}")

    def get_ibge_codes(self, nome_municipio: str, sigla_uf: str):
        """
        Passo 2: Usa a API pública do IBGE para encontrar os códigos pelo nome (Método mais robusto).
        """
        print(f"--- API IBGE: Buscando códigos para '{nome_municipio} - {sigla_uf}' ---")
        
        try:
            url = f"https://servicodados.ibge.gov.br/api/v1/localidades/estados/{sigla_uf}/municipios"
            response = requests.get(url, timeout=10)
            response.raise_for_status()
            municipios_list = response.json()
            
            def normalizar(texto):
                if not texto: return ""
                texto = unicodedata.normalize('NFD', texto)
                texto = re.sub(r'[\u0300-\u036f]', '', texto)
                return texto.lower().strip()

            nome_normalizado = normalizar(nome_municipio)
            
            for municipio in municipios_list:
                nome_ibge_normalizado = normalizar(municipio['nome'])
                if nome_ibge_normalizado == nome_normalizado:
                    codigo_municipio = str(municipio['id'])
                    codigo_uf = str(municipio['microrregiao']['mesorregiao']['UF']['id'])
                    
                    print(f"--- API IBGE: Códigos encontrados: UF={codigo_uf}, Município={codigo_municipio} ---")
                    return {
                        "codigo_uf": int(codigo_uf),
                        "sigla_uf": sigla_uf,
                        "codigo_municipio": codigo_municipio, 
                        "nome_municipio": municipio['nome']
                    }
            
            print(f"--- API IBGE: ERRO - Município '{nome_normalizado}' não encontrado na lista da UF '{sigla_uf}' ---")
            raise HTTPException(status_code=404, detail=f"Município '{nome_municipio}' não encontrado na API do IBGE para a UF '{sigla_uf}'.")
                
        except requests.exceptions.RequestException as e:
            print(f"Erro ao chamar a API do IBGE: {e}")
            raise HTTPException(status_code=504, detail=f"Falha ao chamar API do IBGE: {e}")

    def get_estabelecimentos_por_municipio(self, codigo_municipio: str):
        """
        Passo 3: Usa a API DEMAS (real) que você encontrou, filtrando pelo código do município.
        """
        demas_url = "https://apidadosabertos.saude.gov.br/assistencia-a-saude/"
        demas_params = {"codigo_municipio": codigo_municipio}

        print(f"--- API DEMAS: Buscando estabelecimentos para o município {codigo_municipio} (timeout=15s) ---")

        try:
            response = requests.get(demas_url, params=demas_params, timeout=15)
            response.raise_for_status()
            data = response.json()
            # ... (Lógica de fallback para CNES, etc.) ...
            # O resto da sua função estava correto.
            # (Vou colar a sua função completa aqui para garantir)
            
            estabelecimentos_formatados = []
            if 'estabelecimentos' not in data:
                 print(f"--- API DEMAS: Resposta OK, mas sem a chave 'estabelecimentos'. Total: 0 ---")
                 # Não retorna, tenta o fallback
                 raise Exception("Chave 'estabelecimentos' não encontrada no DEMAS")

            for item in data.get('estabelecimentos', []):
                lat_val = item.get('latitude_estabelecimento_decimo_grau')
                lon_val = item.get('longitude_estabelecimento_decimo_grau')

                if (lat_val and lon_val and lat_val != 0.0 and lon_val != 0.0):
                    try:
                        estabelecimentos_formatados.append({
                            "id": item.get('co_unidade'),
                            "nome": item.get('nome_razao_social'),
                            "endereco": f"{item.get('endereco_estabelecimento', '')}, {item.get('numero_estabelecimento', '')} - {item.get('bairro_estabelecimento', '')}",
                            "latitude": float(lat_val),
                            "longitude": float(lon_val),
                            "_fonte": "demas",
                        })
                    except (ValueError, TypeError):
                        pass

            print(f"--- API DEMAS: Encontrados {len(estabelecimentos_formatados)} estabelecimentos com lat/lon válidas. ---")
            return estabelecimentos_formatados

        except Exception as e:
            print(f"--- API DEMAS falhou ({e}), tentando fallback CNES por codigo_municipio={codigo_municipio} ---")
            try:
                cnes_url = "https://apidadosabertos.saude.gov.br/cnes/estabelecimentos"
                cnes_params = {"codigo_municipio": codigo_municipio, "status": "1", "offset": "0"}
                resp = requests.get(cnes_url, params=cnes_params, timeout=15)
                resp.raise_for_status()
                j = resp.json()
                itens = j.get('estabelecimentos', [])

                estabelecimentos_formatados = []
                for item in itens:
                    try:
                        lat_val = item.get('latitude_estabelecimento_decimo_grau')
                        lon_val = item.get('longitude_estabelecimento_decimo_grau')
                        if lat_val and lon_val and float(lat_val) != 0.0 and float(lon_val) != 0.0:
                            estabelecimentos_formatados.append({
                                "id": item.get('codigo_cnes') or item.get('codigo_estabelecimento_saude'),
                                "nome": item.get('nome_fantasia') or item.get('nome_razao_social'),
                                "endereco": f"{item.get('endereco_estabelecimento','')}, {item.get('numero_estabelecimento','')} - {item.get('bairro_estabelecimento','')}",
                                "latitude": float(lat_val),
                                "longitude": float(lon_val),
                                "_fonte": "cnes",
                            })
                    except (ValueError, TypeError):
                        continue

                print(f"--- CNES fallback: Encontrados {len(estabelecimentos_formatados)} estabelecimentos para municipio {codigo_municipio}. ---")
                return estabelecimentos_formatados
            except Exception as e2:
                print(f"!!!!!!!! ERRO GERAL AO CHAMAR CNES (fallback) !!!!!!!!")
                print(f"Erro CNES: {e2}")
                raise HTTPException(status_code=504, detail=f"Falha ao buscar dados do DEMAS e CNES: {e} / {e2}")
    
    def enviar_notificacao_push(self, device_token: str, titulo: str, mensagem: str):
        """
        Envia uma notificação push para um dispositivo específico via Firebase Cloud Messaging (FCM).
        """
        print(f"--- FCM: Tentando enviar notificação para o token: {device_token[:10]}... ---")
        
        if not self.fcm_server_key:
            print("--- FCM ERRO: Chave do servidor FCM não configurada no .env ---")
            return {"erro": "Chave do servidor FCM não configurada."}

        url = "https://fcm.googleapis.com/fcm/send"
        headers = {
            "Authorization": f"key={self.fcm_server_key}",
            "Content-Type": "application/json",
        }
        payload = {
            "to": device_token, 
            "notification": { "title": titulo, "body": mensagem, "sound": "default" },
            "data": { "tipo": "alerta_saude", "id_campanha": "1234" }
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