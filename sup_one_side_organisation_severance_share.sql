CREATE FUNCTION sup_one_side_organisation_severance_share (@SupID INT)

/*
Репутация поставщика. Доля контрактов с разрывом отношений в одностороннем порядке по решению заказчика, а именно:
8326974 - По решению заказчика в одностороннем порядке
8361022 - Решение заказчика об одностороннем отказе от исполнения контракта
8724082 - Односторонний отказ заказчика от исполнения контракта в соответствии с гражданским законодательством
*/

RETURNS FLOAT
AS
BEGIN
  DECLARE @share_of_bad_contracts FLOAT
  DECLARE @num_of_all_finished_contracts FLOAT
  
  SET @share_of_bad_contracts = (
    SELECT COUNT(cntr.ID)
    FROM f_OOS_Value AS val
    INNER JOIN DV.d_OOS_Suppliers AS sup ON sup.ID = val.RefSupplier
    INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
    LEFT JOIN DV.d_OOS_ClosContracts As cntrCls ON cntrCls.RefContract = cntr.ID
    INNER JOIN DV.fx_OOS_ContractStage AS st ON st.ID = cntr.RefStage
    INNER JOIN DV.d_OOS_TerminReason AS t ON t.ID = cntrCls.RefTerminReason
    LEFT JOIN DV.d_OOS_Penalties AS p ON p.RefContract = cntr.ID
    WHERE t.Code IN (8326974,8361022,8724082) AND sup.ID = @SupID
  )
  
  SET @num_of_all_finished_contracts = (
      SELECT COUNT(cntr.ID)
      FROM f_OOS_Value AS val
      INNER JOIN DV.d_OOS_Suppliers AS sup ON sup.ID = val.RefSupplier
      INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
      LEFT JOIN DV.d_OOS_ClosContracts As cntrCls ON cntrCls.RefContract = cntr.ID
      INNER JOIN DV.fx_OOS_ContractStage AS cntrSt ON cntrSt.ID = cntr.RefStage
      WHERE sup.ID = @SupID AND cntrSt.ID IN (3, 4)
  )
  
  RETURN @share_of_bad_contracts / @num_of_all_finished_contracts
END