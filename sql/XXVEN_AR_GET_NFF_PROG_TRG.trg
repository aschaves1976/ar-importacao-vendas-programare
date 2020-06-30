CREATE OR REPLACE TRIGGER XXVEN_AR_GET_NFF_PROG_TRG
 AFTER INSERT OR UPDATE ON ra_customer_trx_all
 REFERENCING NEW AS NEW OLD AS OLD
 FOR EACH ROW
 WHEN (     NEW.interface_header_context = 'PROGRAMARE'
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
   --
BEGIN

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
  UPDATE tb_prog_ebs_ped_venda_cab@intprd
    SET    codigo_pedido_oracle = :new.customer_trx_id
	     , status_integracao    = 40
  WHERE 1=1
    AND chave_nfe = :new.interface_header_attribute11
    AND nfe       = :new.trx_number
  ;
END;
/