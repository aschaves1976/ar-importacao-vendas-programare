CREATE OR REPLACE PACKAGE BODY  XXVEN_AR_INTERF_PROGRAMARE_PK AS
-- +=================================================================+
-- |                 ORACLE, RIO DE JANEIRO, BRASIL                  |
-- |                       ALL RIGHTS RESERVED.                      |
-- +=================================================================+
-- | FILENAME                                                        |
-- |  XXVEN_AR_INTERF_PROGRAMARE_PK.pkb                              |
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
-- |                                                                 |
-- |   Alessandro Chaves   / 2020-06-27                              |
-- |    Nota será emitida pelo Procfit e TaxWeb, com isso o número   |
-- |    da nota já existirá e deve ser enviado para a interface do   |
-- |    AR, para o campo TRX_NUMBER                                  |
-- |                                                                 |
-- +=================================================================+
--
  PROCEDURE P_DEBUG(v_text VARCHAR2) AS
  BEGIN
     --IF L_DEBUG <> 'N' THEN
     fnd_file.put_line(fnd_file.log, v_text);
     --END IF;
  END P_DEBUG;
  --
  --
  PROCEDURE gera_nf_receivables (p_typ_ra_interface_lines_all IN l_tab_ra_interface_lines_all
                               , p_mens_erro                  OUT  NOCOPY VARCHAR2 ) AS
     --
     l_mens_erro                   VARCHAR2 (500);
     l_tb_rec_ra_interface_lines   l_tab_ra_interface_lines_all;
     l_pedido                      VARCHAR2 (50);
     l_ind                         BINARY_INTEGER;
     --
  BEGIN
     --
     l_tb_rec_ra_interface_lines.DELETE;
     l_tb_rec_ra_interface_lines := p_typ_ra_interface_lines_all;
     --
     l_mens_erro := 'Erro inserindo linhas na tabela de open interface AR (ra_interface_lines_all). Pedido Venda Programare: ';
     l_ind       := l_tb_rec_ra_interface_lines.FIRST;
     WHILE l_ind IS NOT NULL 
     LOOP
        l_pedido := l_tb_rec_ra_interface_lines(l_ind).interface_line_attribute1;
        INSERT INTO ra_interface_lines_all
             VALUES l_tb_rec_ra_interface_lines(l_ind);
        l_ind := l_tb_rec_ra_interface_lines.NEXT(l_ind);
     END LOOP;
     --
     p_mens_erro := NULL;
     --
  EXCEPTION
     WHEN OTHERS THEN
        --
        p_mens_erro := l_mens_erro || l_pedido || '. ' || SUBSTR(SQLERRM, 1, 200);
        --
  END gera_nf_receivables;
  --
  --
  PROCEDURE movimenta_estoque( p_inventory_item_id  IN NUMBER
                             , p_qtde               IN NUMBER
                             , p_uom                IN VARCHAR2
                             , p_organization_id    IN NUMBER
                             , p_cost_of_sales_acc  IN NUMBER
                             , x_msg_error          OUT NOCOPY VARCHAR2) IS
     --
     l_msg_error                   VARCHAR2(1000);
     e_error                       EXCEPTION;
     --
     l_transaction_type_id_inv     mtl_transaction_types.transaction_type_id%TYPE;
     l_transaction_type_name       mtl_transaction_types.transaction_type_name%TYPE;
     l_transaction_interface_id    NUMBER;
     l_lot_control_code            mtl_system_items_b.lot_control_code%TYPE;
     l_serial_number_control_code  mtl_system_items_b.serial_number_control_code%TYPE;
     l_subinventory_code           mtl_secondary_inventories.secondary_inventory_name%TYPE;
     l_quantidade                  NUMBER;
     --
  BEGIN
     --
     l_quantidade := p_qtde * -1;
     --
     P_DEBUG('  ');
     P_DEBUG(' Processo Movimenta Material');
     P_DEBUG(' Parametros');
     P_DEBUG(' Inventory Item Id: ' || p_inventory_item_id);
     P_DEBUG(' Quantity         : ' || l_quantidade);
     P_DEBUG(' Uom              : ' || p_uom);
     P_DEBUG(' Cost of Sales Acc: ' || p_cost_of_sales_acc);

     -- TIPO DE TRANSACAO INV
     --
     BEGIN
        P_DEBUG(' ');
        P_DEBUG(' Selecionando tipo de transacao (Venda PROGRAMARE)');
        SELECT mtt.transaction_type_id
             , mtt.transaction_type_name
          INTO l_transaction_type_id_inv
             , l_transaction_type_name
          FROM mtl_transaction_types      mtt
         WHERE TRANSACTION_TYPE_NAME = 'Venda PROGRAMARE' ;
        --
        P_DEBUG(' ID transacao  : ' || l_transaction_type_id_inv);
        P_DEBUG(' Nome transacao: ' || l_transaction_type_name);
        P_DEBUG(' ');
        --
     EXCEPTION WHEN OTHERS THEN
        l_msg_error := ' Erro ao selecionar informacoes sobre tipo de transacao (Venda PROGRAMARE): ' || SUBSTR(SQLERRM,1,150);
        RAISE e_error;
     END;
     --      
     BEGIN
        SELECT mtl_material_transactions_s.nextval
          INTO l_transaction_interface_id
          FROM dual;
        --
        P_DEBUG(' Sequencia mtl_material_transactions_s: '|| l_transaction_interface_id);
        P_DEBUG(' ');
        --
     EXCEPTION WHEN OTHERS THEN
        l_msg_error := ' Erro ao selecionar sequencia mtl_material_transactions_s: ' || SUBSTR(SQLERRM,1,150);
        RAISE e_error;
     END;
     --  P_DEBUG('  Selecionando Cost/Lot/Serial na tabela de materiais (mtl_system_items_b): Inventory_Item_ID/Organization_ID: ' || p_inventory_item_id || '/' || p_organization_id);
     --
     BEGIN
        SELECT -- cost_of_sales_account
               lot_control_code
             , serial_number_control_code
          INTO -- l_cost_of_sales_account
               l_lot_control_code
             , l_serial_number_control_code
          FROM mtl_system_items_b
         WHERE inventory_item_id = p_inventory_item_id
           AND organization_id   = p_organization_id;
        --
        -- P_DEBUG('  Cost_of Sales Account   : ' || p_cost_of_sales_acc);
        P_DEBUG(' Lot Control Code        : ' || l_lot_control_code);
        P_DEBUG(' Serial Numb Control Code: ' || l_serial_number_control_code);
        --
     EXCEPTION WHEN OTHERS THEN
        l_msg_error := ' Erro ao selecionar informacoes sobre Cost/Lot/Serial na tabela de materiais (mtl_system_items_b): Inventory_Item_ID/Organization_ID: '
                    || p_inventory_item_id || '/' || p_organization_id ||'. ' || SUBSTR(SQLERRM,1,150);
        RAISE e_error;
     END;
     --
     BEGIN
        SELECT secondary_inventory_name
          INTO l_subinventory_code
          FROM mtl_secondary_inventories
         WHERE organization_id          = p_organization_id
           AND secondary_inventory_name IS NOT NULL
           AND ROWNUM                   = 1;
        --
        P_DEBUG(' Suninventario : ' || l_subinventory_code);
        --
     EXCEPTION WHEN OTHERS THEN
        l_msg_error := ' Erro ao selecionar informacoes sobre subinventario (mtl_secondary_inventories): Organization_Id: ' || p_organization_id;
        RAISE e_error;
     END;
     --
     BEGIN
        INSERT INTO MTL_TRANSACTIONS_INTERFACE
              (TRANSACTION_INTERFACE_ID,
               TRANSACTION_HEADER_ID,
               SOURCE_CODE,
               SOURCE_LINE_ID,
               SOURCE_HEADER_ID,
               PROCESS_FLAG,
               VALIDATION_REQUIRED,
               TRANSACTION_MODE,
               LOCK_FLAG,
               LAST_UPDATE_DATE,
               LAST_UPDATED_BY,
               CREATION_DATE,
               CREATED_BY,
               INVENTORY_ITEM_ID,
               ORGANIZATION_ID,
               TRANSACTION_QUANTITY,
               TRANSACTION_UOM,
               TRANSACTION_DATE,
               SUBINVENTORY_CODE,
               --locator_id,
               DISTRIBUTION_ACCOUNT_ID,
               TRANSACTION_TYPE_ID
               --flow_schedule,
               --scheduled_flag
               )
           VALUES
              ( l_transaction_interface_id     -- TRANSACTION_INTERFACE_ID,
              , l_transaction_interface_id     -- TRANSACTION_HEADER_ID
              , 'Venda PROGRAMARE'             -- SOURCE_CODE,
              , l_transaction_interface_id     -- SOURCE_LINE_ID,
              , l_transaction_interface_id     -- SOURCE_HEADER_ID,                 
              , 1                              -- PROCESS_FLAG,
              , 1                              -- VALIDATION_REQUIRED,
              , 3                              -- TRANSACTION_MODE,
              , 2                              -- LOCK_FLAG,
              , SYSDATE                        -- LAST_UPDATE_DATE,
              , fnd_global.user_id             -- LAST_UPDATED_BY,
              , SYSDATE                        -- CREATION_DATE,
              , fnd_global.user_id             -- CREATED_BY,
              , p_inventory_item_id            -- INVENTORY_ITEM_ID,
              , p_organization_id              -- ORGANIZATION_ID,
              , l_quantidade                   -- TRANSACTION_QUANTITY ,
              , p_uom                          -- TRANSACTION_UOM,
              , SYSDATE                        -- TRANSACTION_DATE
              , l_subinventory_code            -- SUBINVENTORY_CODE,
               --2034,                         -- locator_id,
              , p_cost_of_sales_acc            -- DISTRIBUTION_ACCOUNT_ID,
              , l_transaction_type_id_inv      -- TRANSACTION_TYPE_ID ,
               --'Y',                          -- flow_schedule
               --2                             -- scheduled_flag)
              );
        --
        P_DEBUG(' Linha inserida corretamente na tabela de interface (Movimentacao de Materiais - MTL_TRANSACTIONS_INTERFACE)');
        --
     EXCEPTION WHEN OTHERS THEN
        l_msg_error := ' Erro inserindo linha na tabela de interface (Movimentacao de Materiais - MTL_TRANSACTIONS_INTERFACE): ' || SUBSTR(SQLERRM,1,150);
        RAISE e_error;
     END;
     --
     P_DEBUG('  ');
     --
  EXCEPTION
     WHEN e_error THEN
        x_msg_error := l_msg_error;
     WHEN OTHERS THEN
        x_msg_error := ' Erro procedimento MOVIMENTA_ESTOQUE: ' || SUBSTR(SQLERRM,1,150);
  END movimenta_estoque;
  --
  --
  PROCEDURE PROCESSA_PEDIDO_PROGR_P(ERRBUF      OUT VARCHAR2
                                  , RETCODE     OUT NUMBER
                                  , p_pedido_p  IN  VARCHAR2) IS
   --
   l_tipo_oper                    VARCHAR2(5);
   l_orig_system_ship_customer_id NUMBER;
   l_orig_system_ship_address_id  NUMBER;
   l_orig_system_bill_customer_id NUMBER;
   l_orig_system_bill_address_id  NUMBER;
   l_account_number               hz_cust_accounts.account_number%TYPE;
   l_id                           NUMBER;
   l_num_linhas_pedido            NUMBER;
   l_mens_erro                    VARCHAR2(4000);
   e_process_proximo_pedido       EXCEPTION;
   l_uom_code_line                mtl_units_of_measure_vl.uom_code%TYPE;
   l_org_id                       org_organization_definitions.operating_unit%TYPE;
   l_salesrep_id                  jtf_rs_salesreps.salesrep_id%TYPE;
   l_term_id                      ra_terms_b.term_id%TYPE;
   l_inventory_item_id_line       mtl_system_items_b.inventory_item_id%TYPE;
   l_order_source_id              NUMBER;
   l_sold_to_org_id               NUMBER;
   l_sold_from_organization_id    NUMBER;
   l_id_sequencial                NUMBER;
   --
   l_pedido                       VARCHAR2(30);
   l_pedido_intf                  VARCHAR2(30);
   l_freight_code                 wsh_carrier_ship_methods_v.freight_code%TYPE;
   l_ship_method_code             wsh_carrier_ship_methods_v.ship_method_code%TYPE;
   l_total_reg                    NUMBER;
   l_tot_sucess                   NUMBER := 0;
   l_tot_error                    NUMBER := 0;
   l_tot_japrocess                NUMBER := 0;
   l_org_name                     hr_operating_units.name%TYPE;
   l_empresa_pbm                  hz_cust_accounts.account_name%TYPE;
   l_term_id_pag                  ra_terms_b.term_id%TYPE;
   l_inventory_item_id_frete      mtl_system_items_b.inventory_item_id%TYPE;
   l_description_frete            mtl_system_items_b.description%TYPE;
   --
   l_batch_source_id              ra_batch_sources_all.batch_source_id%TYPE;
   l_batch_source_name            ra_batch_sources_all.name%TYPE;
   l_receipt_method_id            NUMBER;
   l_cust_trx_type_id             ra_cust_trx_types_all.cust_trx_type_id%TYPE;
   l_cost_of_sales_acc            mtl_parameters.cost_of_sales_account%TYPE;
   --
   l_codigo_anvisa                ra_interface_lines_all.attribute5%TYPE;
   l_classific_fiscal             mtl_categories.segment1%TYPE;
   l_global_attribute1            ra_customer_trx_lines_all.global_attribute1%TYPE;
   l_global_transac_cond_clas     ra_customer_trx_lines_all.global_attribute1%TYPE;
   l_global_item_origin           ra_customer_trx_lines_all.global_attribute1%TYPE;
   l_global_fiscal_type           ra_customer_trx_lines_all.global_attribute1%TYPE;
   l_global_sit_fed               ra_customer_trx_lines_all.global_attribute1%TYPE;
   l_global_sit_est               ra_customer_trx_lines_all.global_attribute1%TYPE;
   --
   l_legal_entity                 org_organization_definitions.legal_entity%TYPE;
   l_set_of_books_id              org_organization_definitions.set_of_books_id%TYPE;
   l_exist_ped_venda_transp       BOOLEAN;
   l_exist                        VARCHAR2(10);
   l_data_fabricacao              DATE;
   l_quant_regs_atualizados       NUMBER;
   l_chave_item                   NUMBER;
   --
   l_typ_ra_interface_lines      l_tab_ra_interface_lines_all;
   l_ra_interface_lines_all      ra_interface_lines_all%ROWTYPE;

   lv_decription                 fnd_lookup_values.description%TYPE;
   --

    -- CURSORES DO PROGRAMARE -- :
    CURSOR c_ped_header_prog (pc_pedido_programare IN VARCHAR2) IS
      SELECT tpepvc.*
      FROM tb_prog_ebs_ped_venda_cab@intprd tpepvc
      WHERE 1 = 1
        AND tpepvc.status_integracao IS NULL 
        AND tpepvc.motivo_canc_devol IS NULL
        AND tpepvc.organizacao_venda IN (SELECT organization_code
                                           FROM org_organization_definitions
                                          WHERE operating_unit = FND_GLOBAL.ORG_ID)
        AND tpepvc.pedido_venda_programare = NVL(pc_pedido_programare, tpepvc.pedido_venda_programare)
   ORDER BY tpepvc.pedido_venda_programare;
    --
    CURSOR c_ped_line_prog(PC_PED_VENDA_PROG IN VARCHAR2
                         , pc_id_sequencial  IN NUMBER) IS
      SELECT DISTINCT
             1                         ord
           , tpepvl.id_sequencial
           , tpepvl.pedido_venda_programare
           , tpepvl.linha_venda_programare
           , tpepvl.organizacao_venda
           , tpepvl.numero_linha
           , tpepvl.quantidade
           , tpepvl.unidade_medida
           , tpepvl.id_end_cliente_fatu
           , tpepvl.id_end_cliente_entr
           , tpepvl.valor_item
           , tpepvl.codigo_item
           , tpepvl.descricao_princ_ativo
           , tpepvl.data_validade
           , tpepvl.num_lote
           , tpepvl.conversao_uom
           , 0                           valor_ajustado
           , 0                           valor_desconto
           , NVL(tpepvl.valor_item, 0)   valor_total
           , tpepvl.codigo_pbms
           , tpepvl.idpbms
           , tpepvl.id_conta_corrente
           , tpepvl.qtd_lote
           , tpepvl.data_fabricacao
           , tpepvl.valor_frete
           , tpepvl.pmc
        FROM tb_prog_ebs_ped_venda_lin@intprd tpepvl
       WHERE tpepvl.pedido_venda_programare = pc_ped_venda_prog
         AND tpepvl.id_seq_pai              = pc_id_sequencial
         AND tpepvl.status_integracao       IS NULL
      UNION
      SELECT DISTINCT
             2
           , tpepva.id_sequencial
           , tpepvl.pedido_venda_programare
           , tpepvl.linha_venda_programare
           , tpepvl.organizacao_venda
           , tpepvl.numero_linha
           , tpepvl.quantidade
           , tpepvl.unidade_medida
           , tpepvl.id_end_cliente_fatu
           , tpepvl.id_end_cliente_entr
           , tpepvl.valor_item
           , tpepvl.codigo_item
           , tpepvl.descricao_princ_ativo
           , tpepvl.data_validade
           , tpepvl.num_lote
           , tpepvl.conversao_uom
           , tpepva.valor_ajustado
           , tpepva.valor_desconto
           , (NVL(tpepva.valor_desconto, 0) * -1 / tpepvl.quantidade)  valor_total
           , tpepvl.codigo_pbms
           , tpepvl.idpbms
           , tpepvl.id_conta_corrente
           , tpepvl.qtd_lote
           , tpepvl.data_fabricacao
           , 0                                     valor_frete
           , tpepvl.pmc
        FROM tb_prog_ebs_ped_venda_lin@intprd tpepvl
             --
          , (SELECT *
               FROM tb_prog_ebs_ped_venda_ajuste@intprd 
              WHERE pedido_venda_programare = pc_ped_venda_prog
                AND NVL(valor_desconto, 0)  > 0
                AND status_integracao       IS NULL
                AND id_seq_pai              = pc_id_sequencial) tpepva
             --
       WHERE tpepvl.linha_venda_programare  = tpepva.linha_venda_programare
         AND tpepvl.organizacao_venda       = tpepva.organizacao_venda
         AND tpepvl.status_integracao       IS NULL
         AND tpepvl.pedido_venda_programare = pc_ped_venda_prog
         AND tpepvl.id_seq_pai              = pc_id_sequencial
    ORDER BY pedido_venda_programare
           , linha_venda_programare
           , ord ;
    --
    CURSOR c_ped_pag_prog(PC_PED_VENDA_PROG IN VARCHAR2
                        , pc_id_sequencial  IN NUMBER) IS
      SELECT * 
        FROM tb_prog_ebs_ped_venda_pagam@intprd tpepvp
       WHERE tpepvp.pedido_venda_programare = pc_ped_venda_prog
         AND tpepvp.status_integracao       IS NULL
         AND tpepvp.id_seq_pai              = pc_id_sequencial ;
    --
    CURSOR c_ped_transp(pc_ped_venda_prog IN VARCHAR2
                      , pc_id_sequencial  IN NUMBER) IS
      SELECT * 
        FROM tb_prog_ebs_ped_venda_transp@intprd tpepv
       WHERE tpepv.pedido_venda_programare = pc_ped_venda_prog
         AND tpepv.status_integracao       IS NULL
         AND tpepv.id_seq_pai              = pc_id_sequencial ;
  --
  BEGIN
     --
     BEGIN
        mo_global.set_policy_context('S', FND_GLOBAL.ORG_ID);
     END;
     --
    P_DEBUG('  ');
    P_DEBUG('*****  INICIO LOG  *****');
    --
    P_DEBUG('  ');
    P_DEBUG('Pedido PROGRAMARE a ser processado: ' || NVL(p_pedido_p, ' TODOS') );
    P_DEBUG('Operating Unit (Org ID):            ' || FND_GLOBAL.ORG_ID );
    P_DEBUG('  ');
    P_DEBUG('INICIO LOOP HEADER');
    --
    l_total_reg     := 0;
    l_tot_japrocess := 0;
    --
    FOR r_ped_header_prog IN c_ped_header_prog (p_pedido_p)
    LOOP
      --
      l_id := 1;
      l_typ_ra_interface_lines.DELETE;
      --
      P_DEBUG('  ');
      P_DEBUG('  ');
      P_DEBUG(' -------------------------------- ');
      P_DEBUG(' PROCESSANDO PEDIDO :' || r_ped_header_prog.pedido_venda_programare);
      P_DEBUG(' -------------------------------- ');
      l_total_reg := l_total_reg + 1;
      -- Verifica se ja existe o pedido
      l_pedido        := r_ped_header_prog.pedido_venda_programare;
      l_pedido_intf   := '2' || LPAD(l_pedido, 18, '0');
      l_id_sequencial := r_ped_header_prog.id_sequencial;
      BEGIN
         SELECT 'Exist'
           INTO l_exist
           FROM dual
          WHERE EXISTS (SELECT 1
                          FROM ra_customer_trx_all
                         WHERE interface_header_attribute1 = l_pedido
                           AND ct_reference                = l_pedido ) ;
         --
         l_pedido_intf:= l_pedido;
         --
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            --  Compatibilidade para encontrar pedidos ja processados pela interface antiga ("Programare x OM x AR")
            BEGIN
               SELECT 'Exist'
                 INTO l_exist
                 FROM dual
                WHERE EXISTS (SELECT 1
                                FROM ra_customer_trx_all
                               WHERE interface_header_attribute1 = l_pedido_intf
                                 AND ct_reference                = l_pedido_intf ) ;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  l_exist  := NULL;
               WHEN OTHERS THEN
                  l_exist := 'Exist';
            END;
            --
         WHEN OTHERS THEN
            l_exist := 'Exist';
      END;
      --
      --
      IF l_exist IS NULL THEN
         --
         BEGIN
            SELECT 'Exist'
              INTO l_exist
              FROM dual
             WHERE EXISTS (SELECT 1
                             FROM ra_interface_lines_all
                            WHERE interface_line_attribute1 = l_pedido) ;
            --
            l_pedido_intf:= l_pedido;
            --
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               --  Compatibilidade para encontrar pedidos ja processados pela interface antiga ("Programare x OM x AR")
               BEGIN
                  SELECT 'Exist'
                    INTO l_exist
                    FROM dual
                   WHERE EXISTS (SELECT 1
                                   FROM ra_interface_lines_all
                                  WHERE interface_line_attribute1 = l_pedido_intf) ;
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     l_exist  := NULL;
                  WHEN OTHERS THEN
                     l_exist := 'Exist';
               END;
               --
            WHEN OTHERS THEN
               l_exist := 'Exist';
         END;
         --
      END IF;
      --
      --
      IF l_exist IS NOT NULL THEN
         retcode         := 1;
         l_tot_japrocess := l_tot_japrocess + 1;
         l_mens_erro     := ' PEDIDO VENDA PROGRAMARE JA PROCESSADO: ' || l_pedido_intf;
         P_DEBUG(l_mens_erro);
         processa_erro_p(l_id_sequencial, l_mens_erro, 'CAB', l_pedido_intf);
         CONTINUE;
      END IF;
      --
      -- INICIO
      --
      BEGIN
        -- Validacao de empresa_vendedora
        BEGIN
          l_mens_erro := ' Erro ao selecionar informacoes sobre empresa vendedora: ' || LPAD(r_ped_header_prog.empresa_vendedora, 3, '0');
          SELECT ood.organization_id
               , ood.operating_unit
               , hou.name
               , ood.set_of_books_id
               , ood.legal_entity
            INTO l_sold_from_organization_id
               , l_org_id
               , l_org_name
               , l_set_of_books_id
               , l_legal_entity
            FROM org_organization_definitions ood
               , hr_operating_units           hou
           WHERE ood.operating_unit                  = hou.organization_id
             AND LPAD(ood.organization_code, 3, '0') = LPAD(r_ped_header_prog.empresa_vendedora, 3, '0');
        EXCEPTION
          WHEN OTHERS THEN
             l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
             l_tipo_oper := 'CAB';
             RAISE e_process_proximo_pedido;
        END;
        --
        IF r_ped_header_prog.ID_END_CLIENTE_FATU IS NOT NULL AND
           r_ped_header_prog.ID_END_CLIENTE_ENTR IS NOT NULL THEN
          --Busca informacoes de endereco do cliente
          BEGIN
            l_mens_erro := ' Erro ao selecionar informacoes sobre endereco cliente - SHIP_TO (id_end_cliente_entr): ' || r_ped_header_prog.id_end_cliente_entr || '. Org_Id: ' || l_org_id;
            SELECT cust.cust_account_id
                 , acct.cust_acct_site_id
              INTO l_orig_system_ship_customer_id
                 , l_orig_system_ship_address_id
             FROM hz_cust_accounts        cust
                , hz_cust_acct_sites_all  acct
                , hz_cust_site_uses_all   ship
                , hz_party_sites          party_site 
                , hz_locations            loc
                , hz_parties              party
             WHERE cust.cust_account_id   = acct.cust_account_id   
               AND acct.cust_acct_site_id = ship.cust_acct_site_id 
               AND acct.org_id            = ship.org_id   
               AND ship.site_use_code     = 'SHIP_TO' 
               AND cust.status            = 'A' 
               AND loc.location_id        = party_site.location_id 
               AND acct.party_site_id     = party_site.party_site_id 
               AND cust.party_id          = party.party_id 
               AND ship.org_id            = l_org_id
               AND acct.cust_acct_site_id = r_ped_header_prog.id_end_cliente_entr ;
            --
            l_mens_erro := ' Erro ao selecionar informacoes sobre endereco cliente - BILL_TO (id_end_cliente_fatu): ' || r_ped_header_prog.id_end_cliente_fatu || '. Org_Id: ' || l_org_id;
            SELECT cust.cust_account_id
                 , acct.cust_acct_site_id
              INTO l_orig_system_bill_customer_id
                 , l_orig_system_bill_address_id
             FROM hz_cust_accounts        cust
                , hz_cust_acct_sites_all  acct
                , hz_cust_site_uses_all   ship
                , hz_party_sites          party_site 
                , hz_locations            loc
                , hz_parties              party
             WHERE cust.cust_account_id   = acct.cust_account_id   
               AND acct.cust_acct_site_id = ship.cust_acct_site_id 
               AND acct.org_id            = ship.org_id   
               AND ship.site_use_code     = 'BILL_TO' 
               AND cust.status            = 'A' 
               AND loc.location_id        = party_site.location_id 
               AND acct.party_site_id     = party_site.party_site_id 
               AND cust.party_id          = party.party_id 
               AND ship.org_id            = l_org_id
               AND acct.cust_acct_site_id = r_ped_header_prog.id_end_cliente_entr ;
          EXCEPTION
            WHEN OTHERS THEN
               l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
               l_tipo_oper := 'CAB';
               RAISE e_process_proximo_pedido;
          END;
        ELSE
          --
          -- Busca informacoes de endereco do cliente
          BEGIN
            l_mens_erro := ' Erro ao selecionar informacoes sobre endereco cliente - SHIP_TO (id_cliente): ' || r_ped_header_prog.id_cliente || '. Org_Id: ' || l_org_id;
            SELECT cust.cust_account_id
                 , acct.cust_acct_site_id
              INTO l_orig_system_ship_customer_id
                 , l_orig_system_ship_address_id
             FROM hz_cust_accounts        cust
                , hz_cust_acct_sites_all  acct
                , hz_cust_site_uses_all   ship
                , hz_party_sites          party_site 
                , hz_locations            loc
                , hz_parties              party
             WHERE cust.cust_account_id   = acct.cust_account_id   
               AND acct.cust_acct_site_id = ship.cust_acct_site_id 
               AND acct.ORG_ID            = ship.ORG_ID   
               AND ship.SITE_USE_CODE     = 'SHIP_TO' 
               AND cust.status            = 'A' 
               AND loc.location_id        = party_site.location_id 
               AND acct.party_site_id     = party_site.party_site_id 
               AND cust.party_id          = party.party_id 
               AND ship.org_id            = l_org_id
               AND acct.cust_account_id   = r_ped_header_prog.id_cliente
               AND ROWNUM                 < 2 ;
            --
            l_mens_erro := ' Erro ao selecionar informacoes sobre endereco cliente - BILL_TO (id_cliente): ' || r_ped_header_prog.id_cliente || '. Org_Id: ' || l_org_id;
            SELECT cust.cust_account_id
                 , acct.cust_acct_site_id
              INTO l_orig_system_bill_customer_id
                 , l_orig_system_bill_address_id
             FROM hz_cust_accounts        cust
                , hz_cust_acct_sites_all  acct
                , hz_cust_site_uses_all   ship
                , hz_party_sites          party_site 
                , hz_locations            loc
                , hz_parties              party
             WHERE cust.cust_account_id   = acct.cust_account_id   
               AND acct.cust_acct_site_id = ship.cust_acct_site_id 
               AND acct.ORG_ID            = ship.ORG_ID   
               AND ship.SITE_USE_CODE     = 'BILL_TO' 
               AND cust.status            = 'A' 
               AND loc.location_id        = party_site.location_id 
               AND acct.party_site_id     = party_site.party_site_id 
               AND cust.party_id          = party.party_id 
               AND ship.org_id            = l_org_id
               AND acct.cust_account_id   = r_ped_header_prog.id_cliente
               AND ROWNUM                 < 2 ;
          EXCEPTION
            WHEN OTHERS THEN
               l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
               l_tipo_oper := 'CAB';
               RAISE e_process_proximo_pedido;
          END;
        END IF;
        --
        -- Busca informacoes de account_number (cliente)
        BEGIN
          l_mens_erro := ' Erro ao selecionar informacoes sobre Account_Number (id_cliente): ' || r_ped_header_prog.id_cliente;
          SELECT account_number
            INTO l_account_number
            FROM hz_cust_accounts
           WHERE cust_account_id = r_ped_header_prog.id_cliente;
        EXCEPTION
          WHEN OTHERS THEN
             l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
             l_tipo_oper := 'CAB';
             RAISE e_process_proximo_pedido;
        END;
        --
        -- Vendedor default
        BEGIN
          l_mens_erro := ' Erro ao selecionar informacoes sobre vendedor "PROGRAMARE" para Org_Id: ' || l_org_id;
          SELECT jrs.salesrep_id
          INTO l_salesrep_id
          FROM jtf_rs_defresources_v jrd
             , jtf_rs_salesreps jrs
          WHERE jrs.resource_id                     = jrd.resource_id
            AND jrd.attribute1                      = 'PROGRAMARE'
            AND jrs.start_date_active               < SYSDATE
            AND NVL(jrs.end_date_active, SYSDATE+1) > SYSDATE
            AND jrs.org_id                          = l_org_id;
        EXCEPTION
          WHEN OTHERS THEN
             l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
             l_tipo_oper := 'CAB';
             RAISE e_process_proximo_pedido;
        END;
        --
        -- Validacao de payment_term_id nas tabelas RA_TERMS_B e RA_TERMS_TL
        BEGIN
          --
          IF NVL(r_ped_header_prog.canal_vendas,'OUTROS') = 'ATACADO' THEN
            --ATACADO
            l_mens_erro := ' Erro ao selecionar informacoes sobre pagamento "Atacado" (attribute5/descricao_pagamento): ' || r_ped_header_prog.descricao_pagamento;
            SELECT b.term_id
                 , attribute2
              INTO l_term_id
                 , l_receipt_method_id
              FROM ra_terms_b b
              JOIN ra_terms_tl tl
                ON b.term_id = tl.term_id
               AND b.zd_edition_name = tl.zd_edition_name
             WHERE tl.language       = USERENV('LANG')
               AND b.attribute5      = r_ped_header_prog.descricao_pagamento
               AND ROWNUM            = 1;
          ELSE
            -- DELIVERY
            l_mens_erro := ' Erro ao selecionar informacoes sobre pagamento "Delivery" (attribute3/descricao_pagamento): ' || r_ped_header_prog.descricao_pagamento;
            SELECT b.term_id
                 , attribute2
              INTO l_term_id
                 , l_receipt_method_id
              FROM ra_terms_b b
              JOIN ra_terms_tl tl
                ON b.term_id = tl.term_id
               AND b.zd_edition_name = tl.zd_edition_name
             WHERE tl.language       = USERENV('LANG')
               AND b.attribute3      = r_ped_header_prog.descricao_pagamento
               AND ROWNUM            = 1;
          END IF;
          --
        EXCEPTION
          WHEN OTHERS THEN
             l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
             l_term_id   := 7121;
             l_tipo_oper := 'CAB';
             RAISE e_process_proximo_pedido;
        END;
        --
        -- ORDER SOURCE
        BEGIN
          l_mens_erro := ' Erro ao selecionar informacoes sobre origem da ordem *name): "PROGRAMARE"';
          SELECT order_source_id
            INTO l_order_source_id
            FROM oe_order_sources
           WHERE UPPER(name) = 'PROGRAMARE';
        EXCEPTION
          WHEN OTHERS THEN
             l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
             l_tipo_oper := 'CAB';
             RAISE e_process_proximo_pedido;
        END;
        --
        BEGIN
           --
           l_mens_erro := ' Erro ao selecionar informacoes sobre batch source para a organizacao de vendas (Lookup "XXVEN_BATCH_SOURCE_IMP"): ' || r_ped_header_prog.organizacao_venda;
           SELECT rbs.batch_source_id
                , rbs.name
             INTO l_batch_source_id
                , l_batch_source_name
             FROM ra_batch_sources_all rbs
                , fnd_lookup_values    flv
             WHERE flv.tag          = rbs.name
               AND flv.lookup_type  = 'XXVEN_BATCH_SOURCE_IMP'  -- XXVEN_BATCH_SOURCE
               AND flv.language     = 'PTB'
               AND flv.enabled_flag = 'Y'
               AND flv.lookup_code  = r_ped_header_prog.organizacao_venda;
           --
        EXCEPTION
          WHEN OTHERS THEN
             l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
             l_tipo_oper := 'CAB';
             RAISE e_process_proximo_pedido;
        END;
        --
        IF NVL(r_ped_header_prog.pbm_empresa,0) <> '0' THEN
          BEGIN
            l_mens_erro := ' Erro ao selecionar informacoes sobre empresa pbm no cadastro de clientes (hz_cust_accounts.attribute14): ' ||r_ped_header_prog.PBM_EMPRESA;
            SELECT account_name
              INTO l_empresa_pbm
              FROM hz_cust_accounts
             WHERE attribute14 =  r_ped_header_prog.PBM_EMPRESA;
          EXCEPTION
            WHEN OTHERS THEN
               l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
               l_tipo_oper := 'CAB';
               RAISE e_process_proximo_pedido;
          END;
        END IF;
        --
        -- Inicio: ASChaves - 20200627 - Nota será emitida pelo Procfit e TaxWeb
        BEGIN
           l_mens_erro := ' Erro ao selecionar informacoes sobre tipo de ordem na Lookup (XXVEN_TIPO_TRANSA_PROG_EBS): ' || r_ped_header_prog.tipo_ordem;
           SELECT description
             INTO lv_decription
             FROM fnd_lookup_values  flv
           WHERE 1=1
             AND flv.lookup_type = 'XXVEN_TIPO_TRANSA_PROG_EBS'
             AND flv.language    = USERENV('LANG')
             AND lookup_code     = r_ped_header_prog.tipo_ordem
           ;
           --
           BEGIN
             l_mens_erro := ' Erro ao selecionar informacoes sobre entidade legal/tipo de ordem (ra_cust_trx_types_all): ' || l_legal_entity || '/' || lv_decription;
             SELECT cust_trx_type_id 
               INTO l_cust_trx_type_id
               FROM ra_cust_trx_types_all
             WHERE 1=1
               AND name            = lv_decription
               AND legal_entity_id = l_legal_entity
             ;
           EXCEPTION
             WHEN OTHERS THEN
                l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
                l_tipo_oper := 'CAB';
                RAISE e_process_proximo_pedido;
           END;
           --
        EXCEPTION
          WHEN OTHERS THEN
             l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
             l_tipo_oper := 'CAB';
             RAISE e_process_proximo_pedido;
        END;
        -- Inicio: ASChaves - 20200627 - Nota será emitida pelo Procfit e TaxWeb
        --
        l_exist_ped_venda_transp := FALSE;
        l_ra_interface_lines_all := NULL;
        --
        P_DEBUG(' ');
        P_DEBUG(' INICIO LOOP VENDA TRANSPORTE');
        -- ***
        -- SEMPRE havera apenas 1 linha neste loop de transporte, segundo regra de negocio
        -- ***
        FOR r_ped_transp IN c_ped_transp(r_ped_header_prog.pedido_venda_programare
                                       , l_id_sequencial)
        LOOP
           l_exist_ped_venda_transp := TRUE;
           IF r_ped_transp.CNPJ IS NOT NULL THEN
              BEGIN
                 l_mens_erro := ' Erro ao selecionar informacoes sobre transportadora para CNPJ/Organizacao de Venda: ' || r_ped_transp.cnpj || '/' || r_ped_transp.organizacao_venda
                                                                                                                        || '. Razao Social: '       || r_ped_transp.razao_social;
                 SELECT wcsm.freight_code
                      , wcsm.ship_method_code
                   INTO l_freight_code
                      , l_ship_method_code
                   FROM wsh_carrier_ship_methods_v  wcsm
                     , org_freight_vl              ofv
                  WHERE wcsm.freight_code   = ofv.freight_code
                    AND ofv.organization_id = (SELECT organization_id
                                                 FROM mtl_parameters
                                                WHERE organization_code = r_ped_transp.organizacao_venda
                                                  AND ROWNUM = 1 )
                    AND OFV.SOURCE_LANG     = 'PTB'
                    AND TO_NUMBER(OFV.GLOBAL_ATTRIBUTE5) || OFV.GLOBAL_ATTRIBUTE6 || OFV.GLOBAL_ATTRIBUTE7 = REPLACE(REPLACE(REPLACE(r_ped_transp.cnpj,'.'),'/'),'-')
                    AND ROWNUM = 1 ;
                 --
                 l_ra_interface_lines_all.ship_date_actual := SYSDATE;
                 l_ra_interface_lines_all.fob_point        := '0';
                 l_ra_interface_lines_all.ship_via         := l_freight_code;
                 l_ra_interface_lines_all.waybill_number   := '0';
                 --
              EXCEPTION
                 WHEN OTHERS THEN
                    l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
                    l_tipo_oper := 'CAB';
                    RAISE e_process_proximo_pedido;
              END;
           END IF;
           -- FlexFields
           l_ra_interface_lines_all.header_gdf_attr_category := 'JL.BR.ARXTWMAI.Additional Info';
           l_ra_interface_lines_all.header_gdf_attribute9    := r_ped_transp.valor_frete;    -- DESPESAS ACESS?RIA DE FRETE
           l_ra_interface_lines_all.header_gdf_attribute10   := r_ped_transp.valor_seguro;   -- DESPESA ACESS?RIA DE FRETE
           l_ra_interface_lines_all.header_gdf_attribute11   := '';                          -- OUTRAS DESPESAS ACESS?RIAS
           l_ra_interface_lines_all.header_gdf_attribute12   := r_ped_transp.placa_veiculo;  -- PLACA DE LICEN?A
           l_ra_interface_lines_all.header_gdf_attribute13   := r_ped_transp.quantidade;     -- QUANTIDADE DE VOLUME
           l_ra_interface_lines_all.header_gdf_attribute14   := r_ped_transp.especie;        -- TIPO DE VOLUME
           l_ra_interface_lines_all.header_gdf_attribute15   := r_ped_transp.numeracao;      -- N?MERO DE VOLUME
           l_ra_interface_lines_all.header_gdf_attribute16   := REPLACE(r_ped_transp.peso_bruto,',','.');     -- PESO BRUTO TOTAL
           l_ra_interface_lines_all.header_gdf_attribute17   := REPLACE(r_ped_transp.peso_liquido,',','.');   -- PESO L?QUIDO TOTAL
           --
        END LOOP;
        --
        P_DEBUG(' FIM LOOP VENDA TRANSPORTE');
        --
        --
        P_DEBUG('  ');
        P_DEBUG(' INICIO LOOP PAGAMENTO DE PEDIDO');
        -- Leitura pagamento do pedido
        -- ***
        -- SEMPRE havera apenas 1 linha neste loop de pagamento, segundo regra de negocio
        -- ***
        FOR r_ped_pag_prog IN c_ped_pag_prog(r_ped_header_prog.pedido_venda_programare
                                           , l_id_sequencial)
        LOOP
          BEGIN
            SELECT b.term_id
              INTO l_term_id_pag
              FROM ra_terms_b b
              JOIN ra_terms_tl tl
                ON b.term_id         = tl.term_id
               AND b.zd_edition_name = tl.zd_edition_name
             WHERE tl.language       = USERENV('LANG')
               AND b.attribute3      = r_ped_pag_prog.tipo_pagamento;
          EXCEPTION
            WHEN OTHERS THEN
              l_term_id_pag := NULL;
          END;
          --
          -- Inclusao linha de pagamento
          BEGIN
            INSERT INTO XXVEN.XXVEN_OM_FORMAS_PAGTO(
                    order_source_id,
                    orig_sys_document_ref,
                    pdv_serie,
                    loja_tipo,
                    org_id,
                    order_number,
                    ordered_date,
                    tipo_de_pagamento,
                    valor_pago,
                    codigo_modalidade,
                    banco,
                    cheque,
                    codigo_convenio,
                    codigo_filial_convenio,
                    agencia,
                    conta_corrente,
                    numero_devolucao,
                    origem_pagamento,
                    codigo_rede,
                    nsu_sitef,
                    codigo_transacao,
                    numero_documento,
                    numero_doc_cancelado,
                    numero_parcela,
                    valor_operacao,
                    instituicao,
                    nsu_host,
                    autorizacao,
                    term_id
                  ) VALUES
                  (
                    l_order_source_id,                             -- ORDER_SOURCE_ID
                    l_pedido,                                      -- ORIG_SYS_DOCUMENT_REF
                    '',--r_ped_pag_prog.PDV_SERIE,                 -- PDV_SERIE
                    '',--r_ped_pag_prog.LOJA_TIPO,                 -- LOJA_TIPO
                    l_sold_from_organization_id,                   -- ORGANIZATION_ID
                    TO_NUMBER(r_ped_pag_prog.numero_ordem),        -- ORDER_NUMBER
                    r_ped_pag_prog.data_hora,                      -- ORDERED_DATE
                    l_term_id_pag,                                 -- TIPO_DE_PAGAMENTO
                    r_ped_pag_prog.valor_pago,                     -- VALOR_PAGO
                    '',--r_ped_pag_prog.CODIGO_MODALIDADE,         -- CODIGO_MODALIDADE
                    '',--r_ped_pag_prog.BANCO,                     -- BANCO
                    '',--r_ped_pag_prog.CHEQUE,                    -- CHEQUE
                    '',--r_ped_pag_prog.CODIGO_CONVENIO,           -- CODIGO_CONVENIO
                    '',--r_ped_pag_prog.CODIGO_FILIAL_CONVENIO,    -- CODIGO_FILIAL_CONVENIO
                    '',--r_ped_pag_prog.AGENCIA,                   -- AGENCIA
                    '',--r_ped_pag_prog.CONTA_CORRENTE,            -- CONTA_CORRENTE
                    '',--r_ped_pag_prog.NUMERO_DEVOLUCAO,          -- NUMERO_DEVOLUCAO
                    '',--r_ped_pag_prog.ORIGEM_PAGAMENTO,          -- ORIGEM_PAGAMENTO
                    r_ped_pag_prog.codigo_rede,                    -- CODIGO_REDE
                    r_ped_pag_prog.nsu_sitef,                      -- NSU_SITEF
                    r_ped_pag_prog.codigo_transacao,               -- CODIGO_TRANSACAO
                    '',--r_ped_pag_prog.NUMERO_DOCUMENTO,          -- NUMERO_DOCUMENTO
                    '',--r_ped_pag_prog.NUMERO_DOC_CANCELADO,      -- NUMERO_DOC_CANCELADO
                    '',--r_ped_pag_prog.NUMERO_PARCELA,            -- NUMERO_PARCELA
                    '',--r_ped_pag_prog.VALOR_OPERACAO,            -- VALOR_OPERACAO
                    '',--r_ped_pag_prog.INSTITUICAO,               -- INSTITUICAO
                    '',--r_ped_pag_prog.NSU_HOST,                  -- NSU_HOST
                    r_ped_pag_prog.autorizacao,                    -- AUTORIZACAO
                    l_term_id                                      -- TERM_ID
                  );
          EXCEPTION
            WHEN OTHERS THEN
               l_tipo_oper := 'PAG';
               l_mens_erro := ' Erro ao inserir linha na tabela xxven_om_formas_pagto: ' || SUBSTR(SQLERRM,1,150);
               RAISE e_process_proximo_pedido;
          END;
          --
          l_ra_interface_lines_all.header_attribute11 := r_ped_pag_prog.nsu_sitef || '-' || r_ped_pag_prog.autorizacao; -- NSU-AUTORIZACAO
          --
        END LOOP;
        P_DEBUG(' FIM LOOP PAGAMENTO DE PEDIDO');
        P_DEBUG(' ');
        --
        --
        l_num_linhas_pedido := 0;
        --
        P_DEBUG(' INICIO LOOP LINHA PARA PEDIDO');
        FOR r_ped_line_prog IN c_ped_line_prog(r_ped_header_prog.pedido_venda_programare
                                             , l_id_sequencial)
        LOOP
          --
          l_num_linhas_pedido := l_num_linhas_pedido + 1;
          --
          P_DEBUG(' LINHA PROCESSADA: ' || l_num_linhas_pedido);  
          --
          IF (r_ped_line_prog.quantidade - Trunc(r_ped_line_prog.quantidade)) <> 0 THEN
              l_tipo_oper := 'LIN';
              l_mens_erro := ' Quantidade do pedido nao pode estar fracionada: ' || r_ped_line_prog.quantidade;
              RAISE e_process_proximo_pedido;
          END IF;
          --
          -- Validacao unidade medida do barramento
          BEGIN
            l_mens_erro := ' Erro ao selecionar informacoes sobre unidade de medida: ' || r_ped_line_prog.unidade_medida;
            SELECT uom_code
              INTO l_uom_code_line
              FROM mtl_units_of_measure_vl
             WHERE uom_code = r_ped_line_prog.unidade_medida;
          EXCEPTION
            WHEN OTHERS THEN
               l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
               l_tipo_oper := 'LIN';
               RAISE e_process_proximo_pedido;
          END;
          --
          -- Validacao do codigo do item
          BEGIN
            l_mens_erro := ' Erro ao selecionar informacoes sobre item para a organizacao: ' || r_ped_line_prog.codigo_item || '/' || l_sold_from_organization_id;
            SELECT inventory_item_id
                 , description
              INTO l_inventory_item_id_line
                 , l_ra_interface_lines_all.description
              FROM mtl_system_items_b
             WHERE organization_id = l_sold_from_organization_id
               AND segment1        = TO_CHAR(r_ped_line_prog.codigo_item) ;
          EXCEPTION
             WHEN OTHERS THEN
                l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
                l_tipo_oper := 'LIN';
                RAISE e_process_proximo_pedido;
          END;
          --
          -- Codigo ANVISA
          BEGIN
             SELECT SUBSTR(attribute6,-13,13)
               INTO l_codigo_anvisa
               FROM mtl_system_items_b
              WHERE attribute6 IS NOT NULL
                AND inventory_item_id = l_inventory_item_id_line
                AND organization_id   = (SELECT organization_id
                                           FROM mtl_parameters 
                                          WHERE organization_code = 'MST') ;
             --
             IF (LENGTH(NVL(l_codigo_anvisa,'0')) < 13) OR (l_codigo_anvisa = '0000000000000') THEN
                l_codigo_anvisa := '1046500520013' ;
             END IF;
             --
          EXCEPTION
             WHEN NO_DATA_FOUND THEN
                P_DEBUG(' Item nao tem codigo anvisa (l_inventory_item_id/Item), na organizacao mestre: ' || l_inventory_item_id_line || '/' || r_ped_line_prog.codigo_item);
                l_codigo_anvisa := NULL;             
             WHEN OTHERS THEN
                P_DEBUG(' Erro ao selecionar codigo anvisa do item (l_inventory_item_id/Item), na organizacao mestre: ' || l_inventory_item_id_line || '/' || r_ped_line_prog.codigo_item || '. ' || SUBSTR(SQLERRM,1,150) );
                l_codigo_anvisa := NULL;
          END;
          -- Selecionar informacoes fiscais do item e atribuir a linha da nota fiscal
          BEGIN
             l_mens_erro    := ' Erro ao selecionar informacoes sobre tributos do item (inventory_item_id) para a organizacao: ' || r_ped_line_prog.codigo_item || ' (' || l_inventory_item_id_line || ') / '
                                                                                                                                 || l_sold_from_organization_id;
             l_global_attribute1         := NULL;
             l_global_transac_cond_clas  := NULL;
             l_global_item_origin        := NULL;
             l_global_fiscal_type        := NULL;
             l_global_sit_fed            := NULL;
             l_global_sit_est            := NULL;
             SELECT global_attribute1  NADA -- Futura possivel implementacao
                  , global_attribute2  TRANSAC_COND_CLASS
                  , global_attribute3  ITEM_ORIGIN
                  , global_attribute4  FISCAL_TYPE
                  , global_attribute5  SIT_FED
                  , global_attribute6  SIT_EST
               INTO l_global_attribute1
                  , l_global_transac_cond_clas
                  , l_global_item_origin
                  , l_global_fiscal_type
                  , l_global_sit_fed
                  , l_global_sit_est
               FROM mtl_system_items_b
              WHERE inventory_item_id = l_inventory_item_id_line
                AND organization_id   = l_sold_from_organization_id ;
          EXCEPTION
             WHEN OTHERS THEN
                l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
                l_tipo_oper := 'LIN';
                RAISE e_process_proximo_pedido;
          END;
          --
          IF l_exist_ped_venda_transp THEN
             --
             IF NVL(r_ped_line_prog.valor_frete, 0) > 0 THEN
                -- Validacao do codigo do item FRETE
                BEGIN
                   l_mens_erro := ' Erro ao selecionar informacoes sobre item FRETE para a organizacao: Item frete 64392/' || l_sold_from_organization_id;
                   SELECT inventory_item_id
                        , description
                     INTO l_inventory_item_id_frete
                        , l_description_frete
                     FROM mtl_system_items_b
                    WHERE organization_id = l_sold_from_organization_id
                      AND segment1        = '64392' ;
                EXCEPTION
                   WHEN OTHERS THEN
                      l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
                      l_tipo_oper := 'LIN';
                      RAISE e_process_proximo_pedido;
                END;
             END IF;
             --
          END IF;
          --
          -- Classificacao Fiscal
          BEGIN
             l_mens_erro := ' Erro ao selecionar informacoes sobre classificacao fiscal do item (inventory_item_id) para a organizacao: ' || r_ped_line_prog.codigo_item || ' (' || l_inventory_item_id_line || ') / '
                                                                                                                                          || l_sold_from_organization_id;
             SELECT mc2.segment1
               INTO l_classific_fiscal
               FROM mtl_category_sets    mcs2
                  , mtl_item_categories  mic2
                  , mtl_categories       mc2  
              WHERE mcs2.structure_id       = mc2.structure_id
                AND mc2.category_id         = mic2.category_id
                AND mcs2.category_set_name  = 'FISCAL_CLASSIFICATION'    
                AND mic2.inventory_item_id  = l_inventory_item_id_line
                AND mic2.organization_id    = l_sold_from_organization_id;
          EXCEPTION
             WHEN OTHERS THEN
                l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
                l_tipo_oper := 'LIN';
                RAISE e_process_proximo_pedido;
          END;
          --
          l_ra_interface_lines_all.attribute3 := NULL;
          IF (NVL(r_ped_line_prog.valor_desconto,0) > 0 AND
              NVL(r_ped_line_prog.idpbms,'0') <> '0' )  THEN
             P_DEBUG('DESCONTO PBM ' || r_ped_line_prog.codigo_item);
             l_ra_interface_lines_all.attribute3 := r_ped_line_prog.valor_desconto;
          END IF; 
          --
          IF NVL(r_ped_line_prog.valor_desconto,0) = 0 THEN
             --
             BEGIN
                l_mens_erro := ' Erro ao selecionar informacoes sobre organizacao de venda (mtl_parameters): ' || r_ped_line_prog.organizacao_venda;
                SELECT cost_of_sales_account
                  INTO l_cost_of_sales_acc
                  FROM mtl_parameters
                 WHERE organization_code = r_ped_line_prog.organizacao_venda;
             EXCEPTION
                WHEN OTHERS THEN
                   l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
                   l_tipo_oper := 'LIN';
                   RAISE e_process_proximo_pedido;
             END;
             --
          END IF; 
          --
          l_data_fabricacao := r_ped_line_prog.data_fabricacao;
          IF r_ped_line_prog.data_fabricacao > TRUNC(SYSDATE) THEN
             l_data_fabricacao := TRUNC(SYSDATE);
          END IF;
          --
          l_ra_interface_lines_all.attribute13 := TO_CHAR(l_data_fabricacao,'DD/MM/YYYY');
          l_ra_interface_lines_all.attribute14 := TO_CHAR(r_ped_line_prog.data_validade,'DD/MM/YYYY');
          --
          --
          l_typ_ra_interface_lines(l_id).interface_line_context       := 'PROGRAMARE';
          l_typ_ra_interface_lines(l_id).interface_line_attribute1    := l_pedido;
          --
          -- Inicio: ASChaves - 2020-06-27 --
		  l_typ_ra_interface_lines(l_id).trx_number                   := r_ped_header_prog.nfe;
		  l_typ_ra_interface_lines(l_id).interface_line_attribute11   := r_ped_header_prog.chave_nfe;
          -- Fim: ASChaves - 2020-06-27 --
          --
          l_typ_ra_interface_lines(l_id).interface_line_attribute2    := xxven_ar_intf_programare_ar_s.NEXTVAL;
          l_typ_ra_interface_lines(l_id).interface_line_attribute3    := l_pedido;
          l_typ_ra_interface_lines(l_id).interface_line_attribute4    := r_ped_header_prog.id_sequencial;
          l_typ_ra_interface_lines(l_id).interface_line_attribute5    := r_ped_line_prog.id_sequencial;
          --
          -- AJUSTES DESCONTO
          IF NVL(r_ped_line_prog.valor_desconto,0) > 0 THEN
             l_ra_interface_lines_all.description                     := 'DESCONTO';
             l_typ_ra_interface_lines(l_id).interface_line_attribute6 := l_chave_item;
             l_typ_ra_interface_lines(l_id).interface_line_attribute7 := 'AJUSTE';
          ELSE
             l_typ_ra_interface_lines(l_id).interface_line_attribute6 := 0;
             l_typ_ra_interface_lines(l_id).interface_line_attribute7 := 'ITEM';
             l_chave_item := xxven_ar_intf_programare_ar_s.CURRVAL;
          END IF;
          --
          --
          l_typ_ra_interface_lines(l_id).batch_source_name            := l_batch_source_name;
          l_typ_ra_interface_lines(l_id).set_of_books_id              := l_set_of_books_id;
          l_typ_ra_interface_lines(l_id).line_type                    := 'LINE';
          l_typ_ra_interface_lines(l_id).description                  := l_ra_interface_lines_all.description;
          l_typ_ra_interface_lines(l_id).currency_code                := 'BRL';
          l_typ_ra_interface_lines(l_id).amount                       := ROUND((r_ped_line_prog.quantidade * r_ped_line_prog.valor_total), 2);
          l_typ_ra_interface_lines(l_id).cust_trx_type_id             := l_cust_trx_type_id;
          l_typ_ra_interface_lines(l_id).term_id                      := l_term_id;
          --
          l_typ_ra_interface_lines(l_id).orig_system_bill_customer_id := l_orig_system_bill_customer_id;
          l_typ_ra_interface_lines(l_id).orig_system_bill_address_id  := l_orig_system_bill_address_id;
          l_typ_ra_interface_lines(l_id).orig_system_ship_customer_id := l_orig_system_ship_customer_id;
          l_typ_ra_interface_lines(l_id).orig_system_ship_address_id  := l_orig_system_ship_address_id;
          l_typ_ra_interface_lines(l_id).orig_system_sold_customer_id := r_ped_header_prog.id_cliente;
          --
          l_typ_ra_interface_lines(l_id).receipt_method_id            := l_receipt_method_id;
          l_typ_ra_interface_lines(l_id).conversion_type              := 'User';
          l_typ_ra_interface_lines(l_id).conversion_rate              := '1';
          l_typ_ra_interface_lines(l_id).trx_date                     := SYSDATE;
          l_typ_ra_interface_lines(l_id).line_number                  := l_id;
          l_typ_ra_interface_lines(l_id).quantity                     := r_ped_line_prog.quantidade;
          l_typ_ra_interface_lines(l_id).quantity_ordered             := r_ped_line_prog.quantidade;
          l_typ_ra_interface_lines(l_id).unit_selling_price           := r_ped_line_prog.valor_total;
          l_typ_ra_interface_lines(l_id).unit_standard_price          := r_ped_line_prog.valor_total;
          -- Frete no cabecalho
          l_typ_ra_interface_lines(l_id).ship_date_actual             := l_ra_interface_lines_all.ship_date_actual;
          l_typ_ra_interface_lines(l_id).fob_point                    := l_ra_interface_lines_all.fob_point;
          l_typ_ra_interface_lines(l_id).ship_via                     := l_ra_interface_lines_all.ship_via;
          l_typ_ra_interface_lines(l_id).waybill_number               := l_ra_interface_lines_all.waybill_number;
          --
          l_typ_ra_interface_lines(l_id).primary_salesrep_id          := l_salesrep_id;
--          l_typ_ra_interface_lines(l_id).purchase_order               := r_ped_header_prog.pedido_compra;
          l_typ_ra_interface_lines(l_id).inventory_item_id            := l_inventory_item_id_line;
          l_typ_ra_interface_lines(l_id).comments                     := r_ped_header_prog.obs;
          -- 
          l_typ_ra_interface_lines(l_id).attribute1                   := r_ped_line_prog.id_conta_corrente;
          l_typ_ra_interface_lines(l_id).attribute3                   := l_ra_interface_lines_all.attribute3;          -- valor desconto
          l_typ_ra_interface_lines(l_id).attribute5                   := l_codigo_anvisa;
          l_typ_ra_interface_lines(l_id).attribute8                   := l_pedido;
          l_typ_ra_interface_lines(l_id).attribute9                   := r_ped_line_prog.pmc;
          --
          r_ped_line_prog.descricao_princ_ativo                       := xxven_ebs_util_pk.fun_ret_palavra_sem_acento(r_ped_line_prog.descricao_princ_ativo);
          IF LENGTHB(r_ped_line_prog.descricao_princ_ativo) > 150 THEN --  150 = Tamanho do campo destino ATTRIBUTE10
             --
             l_mens_erro := 'Tamanho do campo descricao principio ativo excede o tamnanho do campo destino (ATTRIBUTE10 tamanho 150 posicoes)';
             l_tipo_oper := 'LIN';
             RAISE e_process_proximo_pedido;
             --
          END IF;
          --
          l_typ_ra_interface_lines(l_id).attribute10                  := r_ped_line_prog.descricao_princ_ativo;
          l_typ_ra_interface_lines(l_id).attribute11                  := r_ped_line_prog.num_lote;
          l_typ_ra_interface_lines(l_id).attribute12                  := r_ped_line_prog.qtd_lote;
          l_typ_ra_interface_lines(l_id).attribute13                  := l_ra_interface_lines_all.attribute13;         -- data fabricacao
          l_typ_ra_interface_lines(l_id).attribute14                  := l_ra_interface_lines_all.attribute14;         -- data validade
          l_typ_ra_interface_lines(l_id).attribute15                  := r_ped_line_prog.conversao_uom;
          --
          l_typ_ra_interface_lines(l_id).header_attribute4            := l_empresa_pbm;                                -- nome do convenio/industria
          l_typ_ra_interface_lines(l_id).header_attribute6            := r_ped_header_prog.pbm_autorizacao;            -- codigo de autorizacaoo
          l_typ_ra_interface_lines(l_id).header_attribute8            := r_ped_header_prog.codigo_programa_pbms;
          l_typ_ra_interface_lines(l_id).header_attribute10           := r_ped_header_prog.numero_ordem;               -- nosso_numero boleto bancario
          l_typ_ra_interface_lines(l_id).header_attribute11           := l_ra_interface_lines_all.header_attribute11;  -- NSU-AUTORIZACAO
          l_typ_ra_interface_lines(l_id).header_attribute14           := r_ped_header_prog.num_empenho ;               -- Numero do Empenho
          l_typ_ra_interface_lines(l_id).header_attribute15           := r_ped_header_prog.nome_vendedor_externo ;     -- Nome Vendedor Externo
          --
          l_typ_ra_interface_lines(l_id).uom_code                     := l_uom_code_line;
          l_typ_ra_interface_lines(l_id).tax_exempt_flag              := 'S';
          l_typ_ra_interface_lines(l_id).created_by                   := fnd_global.user_id;
          l_typ_ra_interface_lines(l_id).creation_date                := SYSDATE;
          l_typ_ra_interface_lines(l_id).last_updated_by              := fnd_global.user_id;
          l_typ_ra_interface_lines(l_id).last_update_date             :=  SYSDATE;
          l_typ_ra_interface_lines(l_id).last_update_login            := fnd_global.login_id;
          l_typ_ra_interface_lines(l_id).org_id                       := l_org_id;
          l_typ_ra_interface_lines(l_id).header_gdf_attr_category     := 'JL.BR.ARXTWMAI.Additional Info';
          l_typ_ra_interface_lines(l_id).header_gdf_attribute9        := l_ra_interface_lines_all.header_gdf_attribute9;          -- DESPESAS ACESSORIA DE FRETE
          l_typ_ra_interface_lines(l_id).header_gdf_attribute10       := l_ra_interface_lines_all.header_gdf_attribute10;         -- VALOR SEGURO
          l_typ_ra_interface_lines(l_id).header_gdf_attribute11       := l_ra_interface_lines_all.header_gdf_attribute11;         -- OUTRAS DESPESAS ACESSORIAS
          l_typ_ra_interface_lines(l_id).header_gdf_attribute12       := l_ra_interface_lines_all.header_gdf_attribute12;         -- PLACA DE LICENCA
          l_typ_ra_interface_lines(l_id).header_gdf_attribute13       := l_ra_interface_lines_all.header_gdf_attribute13;         -- QUANTIDADE DE VOLUME
          l_typ_ra_interface_lines(l_id).header_gdf_attribute14       := l_ra_interface_lines_all.header_gdf_attribute14;         -- TIPO DE VOLUME
          l_typ_ra_interface_lines(l_id).header_gdf_attribute15       := l_ra_interface_lines_all.header_gdf_attribute15;         -- N?MERO DE VOLUME
          l_typ_ra_interface_lines(l_id).header_gdf_attribute16       := l_ra_interface_lines_all.header_gdf_attribute16;         -- PESO BRUTO TOTAL
          l_typ_ra_interface_lines(l_id).header_gdf_attribute17       := l_ra_interface_lines_all.header_gdf_attribute16;         -- PESO LIQUIDO TOTAL
          -- Informacoes tributarias/fiscais da linha
          l_typ_ra_interface_lines(l_id).line_gdf_attr_category       := 'JL.BR.ARXTWMAI.Additional Info';
           -- l_typ_ra_interface_lines(l_id).line_gdf_attribute1      := 
          l_typ_ra_interface_lines(l_id).line_gdf_attribute2          := l_classific_fiscal;
          l_typ_ra_interface_lines(l_id).line_gdf_attribute3          := l_global_transac_cond_clas;
          l_typ_ra_interface_lines(l_id).line_gdf_attribute4          := l_global_item_origin;
          l_typ_ra_interface_lines(l_id).line_gdf_attribute5          := l_global_fiscal_type;
          l_typ_ra_interface_lines(l_id).line_gdf_attribute6          := l_global_sit_fed;
          l_typ_ra_interface_lines(l_id).line_gdf_attribute7          := l_global_sit_est;
          l_typ_ra_interface_lines(l_id).warehouse_id                 := l_sold_from_organization_id;
          l_typ_ra_interface_lines(l_id).deferral_exclusion_flag      := NULL;
          --
          --
          -- INFORMACOES DE FRETE
          --
          IF l_exist_ped_venda_transp THEN
             --
             IF NVL(r_ped_line_prog.valor_frete, 0) > 0 THEN
                --
                l_id := l_id + 1;
                --
                l_typ_ra_interface_lines(l_id).interface_line_context       := 'PROGRAMARE';
                l_typ_ra_interface_lines(l_id).interface_line_attribute1    := l_pedido;
                l_typ_ra_interface_lines(l_id).interface_line_attribute2    := xxven_ar_intf_programare_ar_s.NEXTVAL;
                l_typ_ra_interface_lines(l_id).interface_line_attribute3    := l_pedido;
                l_typ_ra_interface_lines(l_id).interface_line_attribute4    := r_ped_header_prog.id_sequencial;
                l_typ_ra_interface_lines(l_id).interface_line_attribute5    := r_ped_line_prog.id_sequencial;
                l_typ_ra_interface_lines(l_id).interface_line_attribute6    := l_chave_item;
                l_typ_ra_interface_lines(l_id).interface_line_attribute7    := 'FRETE';
                --
                l_typ_ra_interface_lines(l_id).batch_source_name            := l_batch_source_name;
                l_typ_ra_interface_lines(l_id).set_of_books_id              := l_set_of_books_id;
                l_typ_ra_interface_lines(l_id).line_type                    := 'LINE'; --aschaves 20200603
                l_typ_ra_interface_lines(l_id).description                  := l_description_frete;
                l_typ_ra_interface_lines(l_id).currency_code                := 'BRL';
                l_typ_ra_interface_lines(l_id).amount                       := ROUND((r_ped_line_prog.quantidade * r_ped_line_prog.valor_frete), 2);
                l_typ_ra_interface_lines(l_id).cust_trx_type_id             := l_cust_trx_type_id;
                l_typ_ra_interface_lines(l_id).term_id                      := l_term_id;
                --
                l_typ_ra_interface_lines(l_id).orig_system_bill_customer_id := l_orig_system_bill_customer_id;
                l_typ_ra_interface_lines(l_id).orig_system_bill_address_id  := l_orig_system_bill_address_id;
                l_typ_ra_interface_lines(l_id).orig_system_ship_customer_id := l_orig_system_ship_customer_id;
                l_typ_ra_interface_lines(l_id).orig_system_ship_address_id  := l_orig_system_ship_address_id;
                l_typ_ra_interface_lines(l_id).orig_system_sold_customer_id := r_ped_header_prog.id_cliente;
                --
                l_typ_ra_interface_lines(l_id).receipt_method_id            := l_receipt_method_id;
                l_typ_ra_interface_lines(l_id).conversion_type              := 'User';
                l_typ_ra_interface_lines(l_id).conversion_rate              := '1';
                l_typ_ra_interface_lines(l_id).trx_date                     := SYSDATE;
                l_typ_ra_interface_lines(l_id).line_number                  := l_id;
                l_typ_ra_interface_lines(l_id).quantity                     := NULL;               -- r_ped_line_prog.quantidade;
                l_typ_ra_interface_lines(l_id).quantity_ordered             := NULL;               -- r_ped_line_prog.quantidade;
                l_typ_ra_interface_lines(l_id).unit_selling_price           := NULL;               -- r_ped_line_prog.valor_total;
                l_typ_ra_interface_lines(l_id).unit_standard_price          := NULL;               -- r_ped_line_prog.valor_total;
                -- Frete no cabecalho
                l_typ_ra_interface_lines(l_id).ship_date_actual             := l_ra_interface_lines_all.ship_date_actual;
                l_typ_ra_interface_lines(l_id).fob_point                    := l_ra_interface_lines_all.fob_point;
                l_typ_ra_interface_lines(l_id).ship_via                     := l_ra_interface_lines_all.ship_via;
                l_typ_ra_interface_lines(l_id).waybill_number               := l_ra_interface_lines_all.waybill_number;
                --
                l_typ_ra_interface_lines(l_id).primary_salesrep_id          := l_salesrep_id;
--                l_typ_ra_interface_lines(l_id).purchase_order               := r_ped_header_prog.pedido_compra;
                l_typ_ra_interface_lines(l_id).inventory_item_id            := l_inventory_item_id_frete;
                l_typ_ra_interface_lines(l_id).comments                     := r_ped_header_prog.obs;
                -- 
                l_typ_ra_interface_lines(l_id).attribute1                   := r_ped_line_prog.id_conta_corrente;
                l_typ_ra_interface_lines(l_id).attribute3                   := l_ra_interface_lines_all.attribute3;          -- valor desconto
                l_typ_ra_interface_lines(l_id).attribute5                   := l_codigo_anvisa;
                l_typ_ra_interface_lines(l_id).attribute8                   := l_pedido;
                l_typ_ra_interface_lines(l_id).attribute9                   := NULL;                                         -- r_ped_line_prog.pmc;
                l_typ_ra_interface_lines(l_id).attribute10                  := r_ped_line_prog.descricao_princ_ativo;
                l_typ_ra_interface_lines(l_id).attribute11                  := r_ped_line_prog.num_lote;
                l_typ_ra_interface_lines(l_id).attribute12                  := r_ped_line_prog.qtd_lote;
                l_typ_ra_interface_lines(l_id).attribute13                  := l_ra_interface_lines_all.attribute13;         -- data fabricacao
                l_typ_ra_interface_lines(l_id).attribute14                  := l_ra_interface_lines_all.attribute14;         -- data validade
                l_typ_ra_interface_lines(l_id).attribute15                  := r_ped_line_prog.conversao_uom;
                --
                l_typ_ra_interface_lines(l_id).header_attribute4            := l_empresa_pbm;                                -- nome do convenio/industria
                l_typ_ra_interface_lines(l_id).header_attribute6            := r_ped_header_prog.pbm_autorizacao;            -- codigo de autorizacaoo
                l_typ_ra_interface_lines(l_id).header_attribute8            := r_ped_header_prog.codigo_programa_pbms;
                l_typ_ra_interface_lines(l_id).header_attribute10           := r_ped_header_prog.numero_ordem;               -- nosso_numero boleto bancario
                l_typ_ra_interface_lines(l_id).header_attribute11           := l_ra_interface_lines_all.header_attribute11;  -- NSU-AUTORIZACAO
                --
                l_typ_ra_interface_lines(l_id).uom_code                     := l_uom_code_line;
                l_typ_ra_interface_lines(l_id).tax_exempt_flag              := 'S';
                l_typ_ra_interface_lines(l_id).created_by                   := fnd_global.user_id;
                l_typ_ra_interface_lines(l_id).creation_date                := SYSDATE;
                l_typ_ra_interface_lines(l_id).last_updated_by              := fnd_global.user_id;
                l_typ_ra_interface_lines(l_id).last_update_date             :=  SYSDATE;
                l_typ_ra_interface_lines(l_id).last_update_login            := fnd_global.login_id;
                l_typ_ra_interface_lines(l_id).org_id                       := l_org_id;
                --
                l_typ_ra_interface_lines(l_id).header_gdf_attr_category     := 'JL.BR.ARXTWMAI.Additional Info';
                l_typ_ra_interface_lines(l_id).header_gdf_attribute9        := l_ra_interface_lines_all.header_gdf_attribute9;          -- DESPESAS ACESSORIA DE FRETE
                l_typ_ra_interface_lines(l_id).header_gdf_attribute10       := l_ra_interface_lines_all.header_gdf_attribute10;         -- VALOR SEGURO
                l_typ_ra_interface_lines(l_id).header_gdf_attribute11       := l_ra_interface_lines_all.header_gdf_attribute11;         -- OUTRAS DESPESAS ACESSORIAS
                l_typ_ra_interface_lines(l_id).header_gdf_attribute12       := l_ra_interface_lines_all.header_gdf_attribute12;         -- PLACA DE LICENCA
                l_typ_ra_interface_lines(l_id).header_gdf_attribute13       := l_ra_interface_lines_all.header_gdf_attribute13;         -- QUANTIDADE DE VOLUME
                l_typ_ra_interface_lines(l_id).header_gdf_attribute14       := l_ra_interface_lines_all.header_gdf_attribute14;         -- TIPO DE VOLUME
                l_typ_ra_interface_lines(l_id).header_gdf_attribute15       := l_ra_interface_lines_all.header_gdf_attribute15;         -- N?MERO DE VOLUME
                l_typ_ra_interface_lines(l_id).header_gdf_attribute16       := l_ra_interface_lines_all.header_gdf_attribute16;         -- PESO BRUTO TOTAL
                l_typ_ra_interface_lines(l_id).header_gdf_attribute17       := l_ra_interface_lines_all.header_gdf_attribute16;         -- PESO LIQUIDO TOTAL
                -- Informacoes tributarias/fiscais da linha
                l_typ_ra_interface_lines(l_id).line_gdf_attr_category       := 'JL.BR.ARXTWMAI.Additional Info';
                -- l_typ_ra_interface_lines(l_id).line_gdf_attribute1          := 
                l_typ_ra_interface_lines(l_id).line_gdf_attribute2          := l_classific_fiscal;
                l_typ_ra_interface_lines(l_id).line_gdf_attribute3          := l_global_transac_cond_clas;
                l_typ_ra_interface_lines(l_id).line_gdf_attribute4          := l_global_item_origin;
                l_typ_ra_interface_lines(l_id).line_gdf_attribute5          := l_global_fiscal_type;
                l_typ_ra_interface_lines(l_id).line_gdf_attribute6          := l_global_sit_fed;
                l_typ_ra_interface_lines(l_id).line_gdf_attribute7          := l_global_sit_est;
                --
                l_typ_ra_interface_lines(l_id).warehouse_id                 := l_sold_from_organization_id;
                l_typ_ra_interface_lines(l_id).deferral_exclusion_flag      := 'Y';
                --
             END IF;
             --
          END IF;
          --
          l_id := l_id + 1;
          --
        END LOOP; --FOR r_ped_line_prog IN c_ped_line_prog(r_ped_header_prog.PEDIDO_VENDA_PROGAMARE) LOOP
        --
        P_DEBUG(' FIM LOOP LINHA PARA PEDIDO');
        --
        -- Verifica se existe linhas no pedido
        IF l_num_linhas_pedido = 0 THEN
           l_tipo_oper := 'CAB';
           l_mens_erro := ' NAO HA LINHA(S) PARA ESTE PEDIDO: ' || l_pedido;
           RAISE e_process_proximo_pedido;
        END IF;
        --
        gera_nf_receivables (l_typ_ra_interface_lines
                           , l_mens_erro);
        --
        IF l_mens_erro IS NULL THEN
           --
           BEGIN
              --
              l_mens_erro := 'Erro ao alterar tabela TB_PROG_EBS_PED_VENDA_CAB@INTPRD para o pedido: ' || l_pedido;
              UPDATE TB_PROG_EBS_PED_VENDA_CAB@INTPRD
                 SET status_integracao = 41, data_integracao = SYSDATE, envio_erro = NULL
               WHERE pedido_venda_programare = l_pedido
                 AND id_sequencial           = l_id_sequencial
                 AND status_integracao IS NULL;
              l_quant_regs_atualizados := SQL%ROWCOUNT;
              --
              l_mens_erro := 'Erro ao alterar tabela TB_PROG_EBS_PED_VENDA_LIN@INTPRD para o pedido: ' || l_pedido;
              UPDATE TB_PROG_EBS_PED_VENDA_LIN@INTPRD
                 SET status_integracao = 40, data_integracao = SYSDATE, envio_erro = NULL
               WHERE pedido_venda_programare = l_pedido
                 AND id_seq_pai              = l_id_sequencial
                 AND status_integracao IS NULL;
              l_quant_regs_atualizados := SQL%ROWCOUNT;
              --
              l_mens_erro := 'Erro ao alterar tabela TB_PROG_EBS_PED_VENDA_AJUSTE@INTPRD para o pedido: ' || l_pedido;
              UPDATE TB_PROG_EBS_PED_VENDA_AJUSTE@INTPRD
                 SET status_integracao = 40, data_integracao = SYSDATE, envio_erro = NULL
               WHERE pedido_venda_programare = l_pedido
                 AND id_seq_pai              = l_id_sequencial
                 AND status_integracao IS NULL;
              l_quant_regs_atualizados := SQL%ROWCOUNT;
              --
              l_mens_erro := 'Erro ao alterar tabela TB_PROG_EBS_PED_VENDA_PAGAM@INTPRD para o pedido: ' || l_pedido;
              UPDATE TB_PROG_EBS_PED_VENDA_PAGAM@INTPRD
                 SET status_integracao = 40, data_integracao = SYSDATE, envio_erro = NULL
               WHERE pedido_venda_programare = l_pedido
                 AND id_seq_pai              = l_id_sequencial
                 AND status_integracao IS NULL;
              l_quant_regs_atualizados := SQL%ROWCOUNT;
              --
              l_mens_erro := 'Erro ao alterar tabela TB_PROG_EBS_PED_VENDA_TRANSP@INTPRD para o pedido: ' || l_pedido;
              UPDATE TB_PROG_EBS_PED_VENDA_TRANSP@INTPRD
                 SET status_integracao = 40, data_integracao = SYSDATE, envio_erro = NULL
               WHERE pedido_venda_programare = l_pedido
                 AND id_seq_pai              = l_id_sequencial
                 AND status_integracao IS NULL;
              l_quant_regs_atualizados := SQL%ROWCOUNT;
              --
              --
              COMMIT;
              P_DEBUG('PEDIDO ' || l_pedido || ' PROCESSADO COM SUCESSO');
              l_tot_sucess := l_tot_sucess + 1;
              --
              --
           EXCEPTION WHEN OTHERS THEN
              l_mens_erro := l_mens_erro || '. ' || SUBSTR(SQLERRM,1,150);
              l_tipo_oper := 'CAB';
              RAISE e_process_proximo_pedido;
           END;
           --
        ELSE
           --
           l_tipo_oper := 'CAB';
           RAISE e_process_proximo_pedido;
           --
        END IF;
        --
        --
      EXCEPTION
         WHEN e_process_proximo_pedido THEN
            --
            retcode     := 1;
            l_tot_error := l_tot_error + 1;
            P_DEBUG(l_mens_erro);
            processa_erro_p (l_id_sequencial, l_mens_erro, l_tipo_oper, l_pedido);
            --
      END;
      --
    END LOOP; 
    --
    --
    P_DEBUG(' ');
    P_DEBUG('FIM LOOP HEADER');
    P_DEBUG(' ');
    fnd_file.put_line(fnd_file.output,'');
    fnd_file.put_line(fnd_file.output,'         RESUMO DO PROCESSO DE IMPORTACAO PROGRAMARE/AR');
    fnd_file.put_line(fnd_file.output,'');
    fnd_file.put_line(fnd_file.output,'         TOTAL DE REGISTROS: ' || l_total_reg);
    fnd_file.put_line(fnd_file.output,'         TOTAL DE SUCESSOS : ' || l_tot_sucess);
    fnd_file.put_line(fnd_file.output,'         JÁ PROCESSADOS    : ' || l_tot_japrocess);
    fnd_file.put_line(fnd_file.output,'         COM DE ERROS      : ' || l_tot_error);
    fnd_file.put_line(fnd_file.output,'');

    fnd_file.put_line(fnd_file.log,'');
    fnd_file.put_line(fnd_file.log,'            RESUMO DO PROCESSO DE IMPORTACAO PROGRAMARE/AR');
    fnd_file.put_line(fnd_file.log,'');
    fnd_file.put_line(fnd_file.log,'            TOTAL DE REGISTROS: ' || l_total_reg);
    fnd_file.put_line(fnd_file.log,'            TOTAL DE SUCESSOS : ' || l_tot_sucess);
    fnd_file.put_line(fnd_file.log,'            JÁ PROCESSADOS    : ' || l_tot_japrocess);
    fnd_file.put_line(fnd_file.log,'            COM DE ERROS      : ' || l_tot_error);
    fnd_file.put_line(fnd_file.log,'');

  EXCEPTION
     WHEN OTHERS THEN
        l_mens_erro := ' ERRO INESPERADO NO PROCESSO PEDIDO PROGRAMARE: ' || SUBSTR(SQLERRM,1,150);
        P_DEBUG(' ');
        P_DEBUG(l_mens_erro);
        retcode     := 2;
        l_tot_error := l_tot_error + 1;
        processa_erro_p(l_id_sequencial, l_mens_erro, 'CAB', l_pedido);
        --
        P_DEBUG(' ');
        P_DEBUG('FIM LOOP HEADER');
        P_DEBUG(' ');
        fnd_file.put_line(fnd_file.output,'');
        fnd_file.put_line(fnd_file.output,'         RESUMO DO PROCESSO DE IMPORTACAO PROGRAMARE/AR');
        fnd_file.put_line(fnd_file.output,'');
        fnd_file.put_line(fnd_file.output,'         TOTAL DE REGISTROS: ' || l_total_reg);
        fnd_file.put_line(fnd_file.output,'         TOTAL DE SUCESSOS : ' || l_tot_sucess);
        fnd_file.put_line(fnd_file.output,'         JÁ PROCESSADOS    : ' || l_tot_japrocess);
        fnd_file.put_line(fnd_file.output,'         COM DE ERROS      : ' || l_tot_error);
        fnd_file.put_line(fnd_file.output,'');
        --
        fnd_file.put_line(fnd_file.log,'');
        fnd_file.put_line(fnd_file.log,'            RESUMO DO PROCESSO DE IMPORTACAO PROGRAMARE/AR');
        fnd_file.put_line(fnd_file.log,'');
        fnd_file.put_line(fnd_file.log,'            TOTAL DE REGISTROS: ' || l_total_reg);
        fnd_file.put_line(fnd_file.log,'            TOTAL DE SUCESSOS : ' || l_tot_sucess);
        fnd_file.put_line(fnd_file.log,'            JÁ PROCESSADOS    : ' || l_tot_japrocess);
        fnd_file.put_line(fnd_file.log,'            COM DE ERROS      : ' || l_tot_error);
        fnd_file.put_line(fnd_file.log,'');
        --
  END PROCESSA_PEDIDO_PROGR_P;
  --
  --
  PROCEDURE PROCESSA_ERRO_P(p_id_sequencial  IN NUMBER
                          , p_error          IN VARCHAR2
                          , p_tipo           IN VARCHAR2 -- CAB-CABECALHO, LIN-LINHA, AJU-AJUSTE, PAG-PAGAMENTO, TRA-TRANSPORTADORA
                          , p_pedido         IN VARCHAR2
                          , p_rep            IN VARCHAR2 DEFAULT 'S') IS
  BEGIN
    --
    ROLLBACK;
    --
    IF p_tipo = 'CAB' THEN
      -- CABECALHO
      BEGIN
        UPDATE TB_PROG_EBS_PED_VENDA_CAB@INTPRD
        SET STATUS_INTEGRACAO = 30,
            DATA_INTEGRACAO   = SYSDATE,
            ENVIO_ERRO        = TRIM(p_error)
        WHERE status_integracao IS NULL
          AND id_sequencial           = p_id_sequencial
          AND pedido_venda_programare = p_pedido ;          
          --
          COMMIT;
          --
      EXCEPTION
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log,' ERRO: AO ALTERAR TABELA TB_PROG_EBS_PED_VENDA_CAB: ' || SUBSTR(SQLERRM,1,150));
      END;
      IF p_rep = 'S' THEN
        processa_erro_p(p_id_sequencial,p_error,'LIN',p_pedido,'N');
        processa_erro_p(p_id_sequencial,p_error,'AJU',p_pedido,'N');
        processa_erro_p(p_id_sequencial,p_error,'PAG',p_pedido,'N');
        processa_erro_p(p_id_sequencial,p_error,'TRA',p_pedido,'N');
      END IF;
    END IF;
    --
    --
    IF p_tipo = 'LIN' THEN
      -- LINHA
      BEGIN
        UPDATE TB_PROG_EBS_PED_VENDA_LIN@INTPRD
        SET STATUS_INTEGRACAO = 30,
            DATA_INTEGRACAO   = SYSDATE,
            ENVIO_ERRO        = TRIM(p_error)
        WHERE status_integracao IS NULL
          AND id_seq_pai              = p_id_sequencial
          AND pedido_venda_programare = p_pedido ;
          --
          COMMIT;
          --
      EXCEPTION
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log,' ERRO: AO ALTERAR TABELA TB_PROG_EBS_PED_VENDA_LIN: ' || SUBSTR(SQLERRM,1,150));
      END;

      IF p_rep = 'S' THEN
        processa_erro_p(p_id_sequencial,p_error,'CAB',p_pedido,'N');
        processa_erro_p(p_id_sequencial,p_error,'AJU',p_pedido,'N');
        processa_erro_p(p_id_sequencial,p_error,'PAG',p_pedido,'N');
        processa_erro_p(p_id_sequencial,p_error,'TRA',p_pedido,'N');
      END IF;

    END IF;
    --
    --
    IF p_tipo = 'AJU' THEN
      -- AJUSTE
      BEGIN
        UPDATE TB_PROG_EBS_PED_VENDA_AJUSTE@INTPRD
        SET STATUS_INTEGRACAO = 30,
            DATA_INTEGRACAO   = SYSDATE,
            ENVIO_ERRO        = TRIM(p_error)
        WHERE status_integracao IS NULL
          AND id_seq_pai              = p_id_sequencial
          AND pedido_venda_programare = p_pedido;
          --
          COMMIT;
          --
      EXCEPTION
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log,' ERRO: AO ALTERAR TABELA TB_PROG_EBS_PED_VENDA_AJUSTE: ' || SUBSTR(SQLERRM,1,150));
      END;
      IF p_rep = 'S' THEN
        processa_erro_p(p_id_sequencial,p_error,'LIN',p_pedido,'N');
        processa_erro_p(p_id_sequencial,p_error,'CAB',p_pedido,'N');
        processa_erro_p(p_id_sequencial,p_error,'PAG',p_pedido,'N');
        processa_erro_p(p_id_sequencial,p_error,'TRA',p_pedido,'N');
      END IF;
    END IF;
    --
    --
    IF p_tipo = 'PAG' THEN
      -- PAGAMENTO
      BEGIN
        UPDATE TB_PROG_EBS_PED_VENDA_PAGAM@INTPRD
        SET STATUS_INTEGRACAO = 30,
            DATA_INTEGRACAO   = SYSDATE,
            ENVIO_ERRO        = TRIM(p_error)
        WHERE status_integracao IS NULL
          AND id_seq_pai              = p_id_sequencial
          AND pedido_venda_programare = p_pedido;
          --
          COMMIT;
          --
      EXCEPTION
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log,' ERRO: AO ALTERAR TABELA TB_PROG_EBS_PED_VENDA_PAGAM: ' || SUBSTR(SQLERRM,1,150));
      END;
      IF p_rep = 'S' THEN
        processa_erro_p(p_id_sequencial,p_error,'LIN',p_pedido,'N');
        processa_erro_p(p_id_sequencial,p_error,'AJU',p_pedido,'N');
        processa_erro_p(p_id_sequencial,p_error,'CAB',p_pedido,'N');
        processa_erro_p(p_id_sequencial,p_error,'TRA',p_pedido,'N');
      END IF;
    END IF;
    --
    --
    IF p_tipo = 'TRA' THEN
      -- TRANSPORTE
      BEGIN
        UPDATE TB_PROG_EBS_PED_VENDA_TRANSP@INTPRD
        SET STATUS_INTEGRACAO = 30,
            DATA_INTEGRACAO   = SYSDATE,
            ENVIO_ERRO        = TRIM(p_error)
        WHERE status_integracao IS NULL
          AND id_seq_pai              = p_id_sequencial
          AND pedido_venda_programare = p_pedido;
          --
          COMMIT;
          --
      EXCEPTION
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log,' ERRO: AO ALTERAR TABELA TB_PROG_EBS_PED_VENDA_PAGAM: ' || SUBSTR(SQLERRM,1,150));
      END;
      IF p_rep = 'S' THEN
        processa_erro_p(p_id_sequencial,p_error,'LIN',p_pedido,'N');
        processa_erro_p(p_id_sequencial,p_error,'AJU',p_pedido,'N');
        processa_erro_p(p_id_sequencial,p_error,'CAB',p_pedido,'N');
        processa_erro_p(p_id_sequencial,p_error,'PAG',p_pedido,'N');
      END IF;
    END IF;
    --
  END PROCESSA_ERRO_P;
--
END XXVEN_AR_INTERF_PROGRAMARE_PK;
/