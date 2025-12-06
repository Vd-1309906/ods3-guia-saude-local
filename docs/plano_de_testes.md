# Plano de Testes e Resultados (TP6 - Entrega Final)

Este documento descreve os casos de teste (TCs) e os resultados da validação das funcionalidades da aplicação "Guia Saúde Local", conforme os requisitos do projeto.

## Requisito: RF01 - Mapa e Geolocalização de Unidades de Saúde

| ID    | Caso de Teste                                    | Passos para Execução                                                               | Resultado Esperado                                                                | Status (TP6) |
| :---- | :----------------------------------------------- | :--------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------- | :-- |
| TC1.1 | Visualizar mapa ao abrir a tela principal        | 1. Abrir o aplicativo.                                                              | 1. O mapa deve ser exibido, ocupando a parte superior da tela.                    | **SUCESSO** |
| TC1.2 | Centralizar mapa na localização do usuário       | 1. Abrir o aplicativo.<br> 2. Conceder a permissão de localização.                  | 1. O mapa deve centralizar automaticamente na localização atual do usuário. | **SUCESSO** |
| TC1.3 | Visualizar marcadores das unidades de saúde      | 1. Abrir o aplicativo.<br> 2. Aguardar o carregamento dos dados da API.            | 1. O mapa deve exibir múltiplos marcadores nas coordenadas das unidades de saúde. | **SUCESSO** |

## Requisito: RF02 - Busca e Filtro de Unidades de Saúde

| ID    | Caso de Teste                                | Passos para Execução                                                                  | Resultado Esperado                                                               | Status (TP6) |
| :---- | :------------------------------------------- | :------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------- | :-- |
| TC2.1 | Filtrar unidades por tipo (ex: "Posto de Saúde") | 1. Na tela do mapa, selecionar o tipo "Posto de Saúde".<br>2. Acionar a busca. | 1. A lista/mapa deve exibir apenas as unidades que correspondem ao tipo selecionado. | **SUCESSO** |
| TC2.2 | Buscar unidade por nome (ex: "UPA")           | 1. Utilizar a barra de busca.<br>2. Digitar "UPA" e confirmar. | 1. A lista/mapa deve ser atualizada para exibir unidades que contêm "UPA" no nome. | **SUCESSO** |
| TC2.3 | Limpar filtro e busca                      | 1. Realizar uma busca ou filtro.<br>2. Tocar no botão para limpar a seleção/busca. | 1. A lista/mapa deve voltar a exibir todas as unidades de saúde próximas.                         | **SUCESSO** |

## Requisito: RF03 - Visualização de Campanhas de Saúde

| ID    | Caso de Teste                              | Passos para Execução                                     | Resultado Esperado                                                                  | Status (TP6) |
| :---- | :----------------------------------------- | :------------------------------------------------------- | :------------------------------------------------------------------------------------ | :-- |
| TC3.1 | Acessar a tela de campanhas                | 1. No menu principal, tocar no ícone de "Campanhas" (megafone).          | 1. O aplicativo deve navegar para a tela que lista as campanhas de saúde. | **SUCESSO** |
| TC3.2 | Visualizar detalhes das campanhas ativas     | 1. Na tela de campanhas, observar a lista. | 1. A lista deve ser preenchida com as campanhas ativas, exibindo título e datas. | **SUCESSO** |

## Requisito: RF04 - Agendamento de Notificações de Dicas de Saúde

| ID    | Caso de Teste                                        | Passos para Execução                                                                                                                              | Resultado Esperado                                                                                                 | Status (TP6) |
| :---- | :--------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------------------- | :-- |
| TC4.1 | Acessar tela de configuração de horário          | 1. Navegar até a tela de Campanhas.<br>2. Tocar no ícone de configurações ou relógio.                                                          | 1. Uma janela/tela deve ser aberta para o usuário selecionar o horário de recebimento das notificações.                 | **SUCESSO** |
| TC4.2 | Salvar horário de notificação preferencial         | 1. Na tela de configuração, selecionar um horário (ex: 10:00).<br>2. Salvar a configuração.                      | 1. O sistema deve confirmar que o horário foi salvo e agendar as notificações para as 10:00 diariamente.                                                      | **SUCESSO** |
| TC4.3 | Receber notificação de dica de saúde no horário agendado | 1. Manter o app fechado ou em segundo plano.<br>2. Aguardar o horário definido (ex: 10:00). | 1. O dispositivo deve receber uma notificação push contendo uma dica de saúde. | **SUCESSO** |
| TC4.4 | Testar notificação na tela de agendamento      | 1. Na tela de configuração de horário, tocar no botão "Testar Notificação". | 1. O dispositivo deve receber imediatamente uma notificação de teste com uma dica de saúde. | **SUCESSO** |

## Requisito: RF05 - Notificação Manual de Dicas de Saúde

| ID    | Caso de Teste                                        | Passos para Execução                                                                                                                              | Resultado Esperado                                                                                                 | Status (TP6) |
| :---- | :--------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------------------- | :-- |
| TC5.1 | Disparar notificação de dica pela tela do Mapa       | 1. Na tela do Mapa, localizar e tocar no botão flutuante (FAB) de notificação.                                                          | 1. O dispositivo deve receber imediatamente uma notificação push contendo uma dica de saúde.                 | **SUCESSO** |
| TC5.2 | Disparar notificação de dica pela tela de Campanhas  | 1. Na tela de Campanhas, localizar e tocar no botão flutuante (FAB) de notificação.                      | 1. O dispositivo deve receber imediatamente uma notificação push contendo uma dica de saúde.                                                      | **SUCESSO** |

