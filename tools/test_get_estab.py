import sys
import os
# ensure repo root is on sys.path so we can import backend
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from backend.external_api_client import ExternalAPIService

svc = ExternalAPIService()
print('>>>> TEST DEMAS/CNES FALLBACK for 310620')
try:
    res = svc.get_estabelecimentos_por_municipio('310620')
    print('RESULT COUNT:', len(res))
    for i, r in enumerate(res[:5]):
        print(i+1, r)
except Exception as e:
    print('EXCEPTION', type(e), e)
