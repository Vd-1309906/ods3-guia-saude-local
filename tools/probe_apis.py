import requests, json

urls=[
 'https://apidadosabertos.saude.gov.br/assistencia-a-saude/unidade-basicas-de-saude?limit=1',
 'https://apidadosabertos.saude.gov.br/assistencia-a-saude/unidades?codigo_municipio=310620',
 'https://apidadosabertos.saude.gov.br/assistencia-a-saude/estabelecimentos?codigo_municipio=310620',
 'https://apidadosabertos.saude.gov.br/assistencia-a-saude/ubs?limit=1',
 'https://apidadosabertos.saude.gov.br/cnes/tipounidades',
 'https://apidadosabertos.saude.gov.br/cnes/estabelecimentos?codigo_tipo_unidade=2&status=1&limit=1&offset=0'
]

for u in urls:
    print('\n==>',u)
    try:
        r = requests.get(u, timeout=15)
        print('STATUS', r.status_code)
        tx = r.text
        # try parse json
        try:
            j = r.json()
            if isinstance(j, dict):
                print('JSON keys:', list(j.keys()))
                # if contains list, show first item summary
                for k,v in j.items():
                    if isinstance(v, list) and v:
                        print('Sample from',k,':', json.dumps(v[0], ensure_ascii=False)[:600])
                        break
            else:
                print('JSON type:', type(j))
        except Exception as e:
            print('BODY PREVIEW:', tx[:500])
    except Exception as e:
        print('ERR', e)
