CREATE OR REPLACE TRIGGER XXVEN_AR_GET_NFF_PROG_TRG
 AFTER INSERT OR UPDATE ON ra_customer_trx_all
 REFERENCING NEW AS NEW OLD AS OLD
 FOR EACH ROW
 WHEN ( NEW.interface_header_context = 'PROGRAMARE'
        AND NEW.complete_flag            = 'Y'
      )
 --
 -- +========================================================================+
 -- |                 VENANCIO, RIO DE JANEIRO, BRASIL                       |
 -- |                       ALL RIGHTS RESERVED.                             |
 -- +========================================================================+
 -- | FILENAME                                                               |
 -- |  XXVEN_AR_GET_NFF_PROG_TRG.trg                                         |
 -- |                                                                        |
 -- | PURPOSE                                                                |
 -- |  Criar Trigger XXVEN_AR_GET_NFF_PROG_TRG                               |
 -- |                                                                        |
 -- | DESCRIPTION                                                            |
 -- |   Este Trigger será disparado sempre que for criado um novo registro   |
 -- |  na RA_CUSTOMER_TRX_ALL, onde a Origem seja uma Venda realizada no     |
 -- |  Programare.                                                           |
 -- |                                                                        |
 -- | PARAMETERS                                                             |
 -- |                                                                        |
 -- | CREATED BY:  Alessandro Chaves    - 2020-06-27                         |
 -- | UPDATED BY:                                                            |
 -- |              <NAME> - <UPDATE_DATE>                                    |
 -- |                                                                        |
 -- +========================================================================+
 --
DECLARE
   --
   w_trx_number                  ra_customer_trx_all.trx_number%type;
   w_printing_last_printed       ra_customer_trx_all.printing_last_printed%type;
   w_interface_header_attribute1 ra_customer_trx_all.interface_header_attribute1%type;
   w_numero_ordem                ra_customer_trx_all.attribute10%type;
   l_ct_reference                ra_customer_trx_all.ct_reference%type;
   l_interface_header_context    ra_customer_trx_all.interface_header_context%TYPE;
   l_cust_trx_type_id            ra_customer_trx_all.cust_trx_type_id%TYPE;
   l_nada                        VARCHAR2(1);
   l_mens_ret                    VARCHAR2(2000);
   lv_description                fnd_lookup_values.description%TYPE;
   
   ln_cnt                        PLS_INTEGER := 0;
   lv_x_return_status            VARCHAR2(32000);
   lv_x_msg_data                 VARCHAR2(32000);
   --
BEGIN
  
  UPDATE AR_PAYMENT_SCHEDULES_ALL
    SET SELECTED_FOR_RECEIPT_BATCH_ID = NULL
  WHERE 1=1
    AND CUSTOMER_TRX_ID = :new.customer_trx_id
    AND SELECTED_FOR_RECEIPT_BATCH_ID = '-999'
  ;
  IF :new.interface_header_attribute11 IS NOT NULL AND :new.trx_number IS NOT NULL THEN
    UPDATE tb_prog_ebs_ped_venda_cab@intprd
      SET  
             codigo_pedido_oracle = :new.customer_trx_id
  	       , status_integracao    = 40
           , data_integracao      = SYSDATE
           , envio_erro           = lv_x_msg_data
    WHERE 1=1
      AND chave_nfe = :new.interface_header_attribute11
      AND nfe       = :new.trx_number
    ;
  ELSE 
    UPDATE tb_prog_ebs_ped_venda_cab@intprd
      SET  
             codigo_pedido_oracle = :new.ct_reference
  	       , status_integracao    = 40
           , data_integracao      = SYSDATE
           , envio_erro           = lv_x_msg_data
    WHERE 1=1
      AND pedido_venda_programare = :new.ct_reference
    ;
  END IF;

/*


  JL_BR_SPED_PUB.UPDATE_ATTRIBUTES
    (
        P_API_VERSION	              => 1.0
      , P_COMMIT	                  => FND_API.G_FALSE
      , P_CUSTOMER_TRX_ID           => :new.customer_trx_id
      , P_ELECT_INV_WEB_ADDRESS     => 'http://www.nfe.fazenda.gov.br/portal/principal.aspx'
      , P_ELECT_INV_STATUS          => '2'
      , P_ELECT_INV_ACCESS_KEY      => :new.interface_header_attribute11
      , P_ELECT_INV_PROTOCOL        => NULL
      , X_RETURN_STATUS             => lv_x_return_status
      , X_MSG_DATA                  => lv_x_msg_data
    )
  ;
  IF lv_x_return_status <> 'S' THEN
    UPDATE tb_prog_ebs_ped_venda_cab@intprd
      SET  
             codigo_pedido_oracle = :new.customer_trx_id
	         , status_integracao    = 30
           , data_integracao      = SYSDATE
           , envio_erro           = 'XXVEN_AR_GET_NFF_PROG_TRG: ' || lv_x_msg_data
    WHERE 1=1
      AND chave_nfe = :new.interface_header_attribute11
      AND nfe       = :new.trx_number
    ;
  ELSE
    UPDATE tb_prog_ebs_ped_venda_cab@intprd
      SET  
             codigo_pedido_oracle = :new.customer_trx_id
	         , status_integracao    = 40
           , data_integracao      = SYSDATE
           , envio_erro           = lv_x_msg_data
    WHERE 1=1
      AND chave_nfe = :new.interface_header_attribute11
      AND nfe       = :new.trx_number
    ;
  END IF;





  SELECT COUNT(*)
    INTO ln_cnt
    FROM jl_br_customer_trx_exts
  WHERE 1=1
    AND customer_trx_id = :new.customer_trx_id
    AND electronic_inv_access_key = :new.interface_header_attribute11
  ;
  IF ln_cnt <=0 THEN
    INSERT INTO jl_br_customer_trx_exts
      (
         customer_trx_id
	     , electronic_inv_web_address
       , electronic_inv_status
       , electronic_inv_access_key
       , last_update_date
       , last_updated_by
       , last_update_login
       , creation_date
       , created_by
      )
      VALUES
        (
            :new.customer_trx_id
          , 'http://www.nfe.fazenda.gov.br/portal/principal.aspx'
          , 2
          , :new.interface_header_attribute11
          , SYSDATE
          , fnd_global.user_id
          , fnd_global.login_id
          , SYSDATE
          , fnd_global.user_id
        )
    ;
  END IF;
*/
END;