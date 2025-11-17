# Plano de Testes - Guia Saúde Local

Este documento descreve os casos de teste (TCs) para validar as funcionalidades da aplicação "Guia Saúde Local", com base nos requisitos funcionais definidos.

## Requisito: RF01 - Mapa de unidades de saúde

| ID    | Caso de Teste                                    | Passos para Execução                                                               | Resultado Esperado                                                                |
| :---- | :----------------------------------------------- | :--------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------- |
| TC1.1 | Visualizar mapa ao abrir a tela principal        | 1. Abrir o aplicativo.                                                              | 1. O mapa deve ser exibido, ocupando a parte superior da tela.                    |
| TC1.2 | Centralizar mapa na localização do usuário       | 1. Abrir o aplicativo.<br> 2. Aceitar a permissão de localização.                  | 1. O mapa deve mover a câmera e centralizar no "ponto azul" da localização atual do usuário. |
| TC1.3 | Visualizar marcadores dos postos carregados      | 1. Abrir o aplicativo.<br> 2. Aguardar o carregamento dos dados da API.            | 1. O mapa deve exibir múltiplos marcadores (pins) vermelhos nas coordenadas dos postos de saúde retornados. |

## Requisito: RF02 - Busca de unidades (Não implementado no TP4)

| ID    | Caso de Teste                                | Passos para Execução                                                                  | Resultado Esperado                                                               |
| :---- | :------------------------------------------- | :------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------- |
| TC2.1 | Busca com termo válido (ex: "UPA")           | 1. Ir para a (futura) tela de busca.<br> 2. Digitar "UPA" no campo de busca.<br> 3. Tocar em "Buscar". | 1. A lista deve ser atualizada e exibir apenas as unidades que contêm "UPA" no nome. |
| TC2.2 | Busca sem resultados (ex: "Xyz123")          | 1. Ir para a (futura) tela de busca.<br> 2. Digitar "Xyz123" no campo de busca.<br> 3. Tocar em "Buscar". | 1. A lista deve ficar vazia ou exibir uma mensagem "Nenhum resultado encontrado".   |
| TC2.3 | Limpar busca                                 | 1. Fazer uma busca pelo termo "UPA".<br> 2. Tocar no "X" para limpar o campo de busca. | 1. A lista deve voltar a exibir todos os postos de saúde.                         |

## Requisito: RF03 - Lista de campanhas de vacinação (Não implementado no TP4)

| ID    | Caso de Teste                              | Passos para Execução                                     | Resultado Esperado                                                                  |
| :---- | :----------------------------------------- | :------------------------------------------------------- | :------------------------------------------------------------------------------------ |
| TC3.1 | Visualizar campanhas ativas                | 1. Navegar para a (futura) tela de "Campanhas".          | 1. A lista deve ser preenchida com as campanhas cuja data atual está dentro do período da campanha. |
| TC3.2 | Não exibir campanhas expiradas             | 1. (Pré-condição: Ter uma campanha expirada no BD).<br> 2. Navegar para a tela de "Campanhas". | 1. A lista **não deve** exibir a campanha que já terminou.                          |
| TC3.3 | Visualizar lista sem campanhas ativas      | 1. (Pré-condição: Não ter campanhas ativas no BD).<br> 2. Navegar para a tela de "Campanhas". | 1. A lista deve ficar vazia ou exibir uma mensagem "Nenhuma campanha ativa no momento". |

## Requisito: RF04 - Receber notificações push

| ID    | Caso de Teste                                        | Passos para Execução                                                                                                                              | Resultado Esperado                                                                                                 |
| :---- | :--------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------------------- |
| TC4.1 | Registar token no servidor ao iniciar o app          | 1. Parar e reiniciar o back-end (uvicorn).<br> 2. Parar e reiniciar o app no telemóvel.                                                          | 1. O log do servidor (uvicorn) deve exibir a mensagem "--- TOKEN DE DISPOSITIVO RECEBIDO: ... ---".                 |
| TC4.2 | Receber notificação com app em segundo plano         | 1. Minimizar o app (ir para o ecrã inicial).<br> 2. Usar o Thunder Client para enviar um POST para /enviar-alerta-geral.                      | 1. O telemóvel deve exibir uma notificação do sistema na bandeja.                                                      |
| TC4.3 | Receber notificação com app aberto (Foreground)      | 1. Manter o aplicativo aberto na tela.<br> 2. Usar o Thunder Client para enviar um POST para /enviar-alerta-geral.                                 | 1. O console de debug do Flutter (no VS Code) deve imprimir as mensagens "Recebi uma mensagem com o app aberto!". |


# Plano de Testes e Resultados (TP5) - Guia Saúde Local

## Requisito: RF01 - Mapa de unidades de saúde

| ID    | Caso de Teste | Passos | Resultado Esperado | **Status do Teste (TP5)** |
| :--- | :--- | :--- | :--- | :--- |
| TC1.1 | Visualizar mapa | Abrir o app. | O mapa carrega. | **SUCESSO:** O mapa abriu e carregou os tiles do Google Maps. |
| TC1.2 | Localização | Dar permissão. | Mapa centraliza no usuário. | **SUCESSO:** O mapa foi para Ribeirão das Neves (local real). |
| TC1.3 | Marcadores | Buscar postos. | Pins vermelhos aparecem. | **SUCESSO:** Os pins apareceram após a busca na API. |

## Requisito: RF02 - Busca de unidades

| ID    | Caso de Teste | Passos | Resultado Esperado | **Status do Teste (TP5)** |
| :--- | :--- | :--- | :--- | :--- |
| TC2.1 | Filtro por Tipo | Selecionar "Posto de Saúde" e buscar. | Lista atualiza. | **SUCESSO:** A lista mostrou apenas postos desse tipo. |
| TC2.2 | Lista filtra Municio. | **SUCESSO:** Apenas postos dentro do raio foram exibidos. |

## Requisito: RF03 - Campanhas (Novo)

| ID    | Caso de Teste | Passos | Resultado Esperado | **Status do Teste (TP5)** |
| :--- | :--- | :--- | :--- | :--- |
| TC3.1 | Navegação | Clicar no ícone de megafone. | Abre tela de campanhas. | **SUCESSO:** A tela abriu corretamente. |
| TC3.2 | Visualização | Verificar lista. | Dados das campanhas visíveis. | **SUCESSO:** 3 campanhas foram listadas. |

## Requisito: RF04 - Notificações

| ID    | Caso de Teste | Passos | Resultado Esperado | **Status do Teste (TP5)** |
| :--- | :--- | :--- | :--- | :--- |
| TC4.1 | Registro | Abrir o app. | Log de registro no backend. | **SEM SUCESSO:** Log "TOKEN RECEBIDO" apareceu no Uvicorn. |
| TC4.2 | Recebimento | Enviar POST via Thunder Client. | Notificação no celular. | **SEM SUCESSO:** Notificação apareceu na bandeja do Android. |