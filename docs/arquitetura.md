![ods3-guia-saude-local-container](https://github.com/user-attachments/assets/b3e734be-904c-4fbc-aa49-05f902f1a3a7)![ods3-guia-saude-local-container](https://github.com/user-attachments/assets/ad529039-005f-41e4-82d9-191a85655fe6)# Documento de Arquitetura de Software - Guia Saúde Local

## 1. Introdução

Este documento descreve a arquitetura de software para o projeto "Guia Saúde Local", um aplicativo móvel focado em facilitar o acesso a informações de saúde confiáveis. A modelagem arquitetural utiliza o **C4 Model** para apresentar o sistema em diferentes níveis de abstração.

## 2. Escolhas Tecnológicas (Stack)

A seleção de tecnologias foi baseada em critérios de performance, maturidade do ecossistema e adequação ao problema.

- **Aplicativo Móvel (Front-end):** **Flutter**. Escolhido por sua alta performance, UI expressiva e a capacidade de gerar um código-base único para Android e iOS, otimizando o desenvolvimento.
- **API (Back-end):** **Python com FastAPI**. FastAPI foi selecionado por ser um dos frameworks web mais rápidos disponíveis, com suporte nativo a programação assíncrona e validação de dados via Pydantic, o que garante uma API robusta e ágil.
- **Banco de Dados:** **PostgreSQL**. Um sistema de gerenciamento de banco de dados relacional poderoso e confiável. A escolha foi reforçada pelo uso da extensão **PostGIS**, que oferece capacidades avançadas para armazenamento e consulta de dados geoespaciais, requisito essencial para as funcionalidades de mapa do aplicativo.

## 3. Projeto Arquitetural (C4 Model)

### Nível 1: Diagrama de Contexto

O diagrama de contexto ilustra como o **Sistema "Guia Saúde Local"** interage com seu usuário principal, o **Paciente/Usuário**, e com os sistemas externos dos quais depende para funcionar.

- **Paciente/Usuário (Person):** Uma pessoa que utiliza o aplicativo para obter informações sobre postos de saúde.
- **Sistemas Externos:**
    - **Google Maps (Software System):** Utilizado para a visualização da localização dos postos de saúde próximos ao usuário.
    - **API DEMAS (Software System):** Fonte externa de dados e informações sobre os postos de saúde, garantindo a confiabilidade das informações (RNF02).
    - **Serviços de Notificação Push (APNS & FCM) (Software System):** Utilizados para enviar os alertas do requisito funcional RF04 para os dispositivos dos usuários.

![ods3-guia-saude-local](https://github.com/user-attachments/assets/ea27bbdb-5eae-4704-92bb-207b57fc10bd)

### Nível 2: Diagrama de Contêineres

Este diagrama detalha a estrutura interna do **Sistema "Guia Saúde Local"**, mostrando seus principais blocos de construção (contêineres) e como eles se comunicam.

- **App Movel (Container: Flutter):** É a interface do sistema, responsável por permitir ao usuário a visualização das informações da API e a localização dos postos no mapa. Ele realiza chamadas HTTP/JSON para o Back End.
- **Back End (Container: Python/FastAPI):** O cérebro do sistema. Fornece todos os dados para o app móvel através de uma API via HTTPs. Ele se comunica com o Banco de Dados para persistência e com as APIs externas.
- **Banco de Dados (Container: PostgreSQL com PostGIS):** Armazena todas as informações sobre unidades de saúde, campanhas, etc. É acessado pelo Back End para leitura e gravação de dados.

![ods3-guia-saude-local-container](https://github.com/user-attachments/assets/e4b19ae8-6981-4bff-92d7-122387fb2545)

### Nível 3: Diagrama de Componentes

Dando um zoom no contêiner **Back End**, o diagrama de componentes detalha seus principais módulos lógicos, suas responsabilidades e como eles interagem para atender às solicitações do App Móvel.

- **API Principal / Roteador:** A porta de entrada da API. Recebe as requisições HTTP e as direciona para os roteadores específicos.
- **Roteador de Unidades / Roteador de Campanhas:** Componentes que lidam com as rotas específicas da aplicação (ex: `/unidades`, `/campanhas`), validando entradas e chamando os serviços correspondentes.
- **Serviço de Unidades / Serviço de Campanhas:** Contêm a lógica de negócio da aplicação. Orquestram as operações, utilizando outros componentes (como repositórios e clientes) para cumprir suas tarefas.
- **Repositório de Dados:** Abstrai toda a comunicação com o Banco de Dados. Isola a lógica de queries (SQL) do resto da aplicação.
- **Cliente do Google Maps / Cliente da API DEMAS:** Componentes especializados em comunicar com as APIs externas, tratando da formatação das requisições e respostas.
- **Serviço de Notificações:** Responsável por formatar e orquestrar o envio de notificações push através dos serviços externos (APNS e FCM).

O fluxo de uma requisição se inicia no `API Principal`, é direcionado para o `Roteador` apropriado, que aciona o `Serviço` correspondente. O serviço, por sua vez, utiliza o `Repositório de Dados` para acessar o banco de dados interno ou os `Clientes` para buscar informações em sistemas externos.

![ods3-guia-saude-local-components](https://github.com/user-attachments/assets/cd861701-3105-49d7-8ca1-b6c3c443d6ee)

## 4. Justificativa do Modelo Escolhido

O **C4 Model** foi escolhido por sua simplicidade e eficácia em comunicar uma arquitetura de software para diferentes públicos. Ele permite uma visualização clara desde a perspectiva mais ampla (Contexto) até os detalhes da estrutura interna (Componentes). Para este trabalho acadêmico, a utilização dos níveis de **Contexto, Contêineres e Componentes** permite transmitir as decisões arquiteturais mais importantes de forma clara e progressivamente detalhada, facilitando o entendimento completo do projeto.
