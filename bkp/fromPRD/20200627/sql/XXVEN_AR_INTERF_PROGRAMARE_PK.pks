--------------------------------------------------------
--  Arquivo criado - Sábado-Junho-27-2020   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Package XXVEN_AR_INTERF_PROGRAMARE_PK
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE PACKAGE "APPS"."XXVEN_AR_INTERF_PROGRAMARE_PK" AUTHID CURRENT_USER AS
-- +=================================================================+
-- |                 ORACLE, RIO DE JANEIRO, BRASIL                  |
-- |                       ALL RIGHTS RESERVED.                      |
-- +=================================================================+
-- | FILENAME                                                        |
-- |  XXVEN_AR_INTERF_PROGRAMARE_PK.pls                              |
-- | PURPOSE                                                         |
-- |  Script de criacao de PACKAGE XXVEN_AR_INTERF_PROGRAMARE_PK     |
-- |                                                                 |
-- | DESCRIPTION                                                     |
-- |   AR - Interface de pedido entre o legado PROGRAMARE/OEBS AR    |
-- |                                                                 |
-- | PARAMETERS                                                      |
-- |                                                                 |
-- | CREATED BY   Marcelo Belfort    / 05.07.2018                    |
-- | UPDATED BY   <NOME DO DESENVOLVEDOR> / <DATA>                   |
-- |              <MOTIVO DA MODIFICACAO>                            |
-- +=================================================================+
--

   --
   TYPE l_tab_ra_interface_lines_all IS TABLE OF ra_interface_lines_all%ROWTYPE
                                     INDEX BY BINARY_INTEGER;
   --
   PROCEDURE processa_erro_p(p_id_sequencial IN NUMBER
                           , p_error         IN VARCHAR2
                           , p_tipo          IN VARCHAR2 -- CAB=CABECALHO, LIN=LINHA, AJU=AJUSTE, PAG=PAGAMENTO
                           , p_pedido        IN VARCHAR2
                           , p_rep           IN VARCHAR2 DEFAULT 'S');

   PROCEDURE processa_pedido_progr_p(errbuf     OUT VARCHAR2
                                   , retcode    OUT NUMBER
                                   , p_pedido_p IN VARCHAR2);

END XXVEN_AR_INTERF_PROGRAMARE_PK;

/
