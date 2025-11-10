import requests
import re
import unicodedata
from fastapi import HTTPException

class ExternalAPIService:
    def __init__(self):
        import os
        from dotenv import load_dotenv
        load_dotenv()
        self.google_api_key = os.getenv("GOOGLE_MAPS_API_KEY")

    def get_municipio_info_por_coordenadas(self, latitude: float, longitude: float):
        """
        Passo 1: Usa o Google Geocoding (reverso) para encontrar o NOME e o ESTADO.
        """
        print(f"--- GOOGLE GEOCODING: Buscando dados para {latitude}, {longitude} ---")
        if not self.google_api_key:
            raise HTTPException(status_code=500, detail="Chave da API do Google Maps não configurada.")

        url = "https://maps.googleapis.com/maps/api/geocode/json"
        params = {
            "latlng": f"{latitude},{longitude}",
            "language": "pt-BR",
            "key": self.google_api_key,
        }

        try:
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            data = response.json()

            if data['status'] == 'OK' and data['results']:
                nome_municipio = None
                sigla_uf = None

                for result in data['results']:
                    for component in result['address_components']:
                        if 'administrative_area_level_2' in component['types']:
                            nome_municipio = component.get('long_name')
                        if 'administrative_area_level_1' in component['types']:
                            sigla_uf = component.get('short_name') or component.get('long_name')

                    if nome_municipio and sigla_uf:
                        break

                print(f"DEBUG: nome_municipio={nome_municipio}, sigla_uf={sigla_uf}")

                if nome_municipio and sigla_uf:
                    print(f"--- GOOGLE GEOCODING: Encontrado: {nome_municipio} - {sigla_uf} ---")
                    return self.get_ibge_codes(nome_municipio, sigla_uf)

            print(f"--- GOOGLE GEOCODING: Erro - {data.get('status')} (Não encontrou Município/UF) ---")
            raise HTTPException(status_code=404, detail="Não foi possível encontrar o município para as coordenadas.")

        except requests.exceptions.RequestException as e:
            print(f"Erro ao chamar a API do Google Geocoding: {e}")
            raise HTTPException(status_code=504, detail=f"Falha ao chamar Google Geocoding: {e}")

    def get_ibge_codes(self, nome_municipio: str, sigla_uf: str):
        """
        Passo 2: Usa a API pública do IBGE para encontrar os códigos pelo nome (Método mais robusto).
        """
        print(f"--- API IBGE: Buscando códigos para '{nome_municipio} - {sigla_uf}' ---")

        try:
            if not sigla_uf:
                raise HTTPException(status_code=400, detail="Sigla da UF não fornecida para busca no IBGE.")

            # 1. Busca todos os municípios daquela UF
            url = f"https://servicodados.ibge.gov.br/api/v1/localidades/estados/{sigla_uf}/municipios"
            response = requests.get(url, timeout=10)
            response.raise_for_status()
            municipios_list = response.json()

            # 2. Normaliza o nome do município para comparação
            def normalizar(texto):
                if not texto:
                    return ""
                texto = unicodedata.normalize('NFD', texto)
                texto = re.sub(r'[\u0300-\u036f]', '', texto)
                return texto.lower().strip()

            nome_normalizado = normalizar(nome_municipio)

            # 3. Tenta correspondência exata
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

            # 4. Se não achou exato, tenta correspondência parcial (casos com acentos ou hífens)
            for municipio in municipios_list:
                nome_ibge_normalizado = normalizar(municipio['nome'])
                if nome_normalizado in nome_ibge_normalizado or nome_ibge_normalizado in nome_normalizado:
                    codigo_municipio = str(municipio['id'])
                    codigo_uf = str(municipio['microrregiao']['mesorregiao']['UF']['id'])
                    print(f"--- API IBGE: Códigos encontrados (match parcial): UF={codigo_uf}, Município={codigo_municipio} ---")
                    return {
                        "codigo_uf": int(codigo_uf),
                        "sigla_uf": sigla_uf,
                        "codigo_municipio": codigo_municipio,
                        "nome_municipio": municipio['nome']
                    }

            # 5. Nenhum match
            print(f"--- API IBGE: ERRO - Município '{nome_municipio}' não encontrado na UF '{sigla_uf}' ---")
            raise HTTPException(
                status_code=404,
                detail=f"Município '{nome_municipio}' não encontrado na API do IBGE para a UF '{sigla_uf}'."
            )

        except requests.exceptions.RequestException as e:
            print(f"Erro ao chamar a API do IBGE: {e}")
            raise HTTPException(status_code=504, detail=f"Falha ao chamar API do IBGE: {e}")
