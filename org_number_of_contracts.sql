CREATE FUNCTION org_number_of_contracts (@OrgID INT)

/*
Количество завершенных контрактов у заказчика
*/

RETURNS INT
AS
BEGIN
  DECLARE @num_of_all_finished_contracts FLOAT
  
  SET @num_of_all_finished_contracts = (
      SELECT COUNT(cntr.ID)
      FROM f_OOS_Value AS val
      INNER JOIN DV.d_OOS_Org AS org ON org.ID = val.RefOrg
      INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
      -- LEFT JOIN DV.d_OOS_ClosContracts As cntrCls ON cntrCls.RefContract = cntr.ID
      INNER JOIN DV.fx_OOS_ContractStage AS cntrStg ON cntrStg.ID = cntr.RefStage
      WHERE org.ID = @OrgID AND cntrStg.ID IN (3, 4)
  )
  
  RETURN @num_of_all_finished_contracts
END