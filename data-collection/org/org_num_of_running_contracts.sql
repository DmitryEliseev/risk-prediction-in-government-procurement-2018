IF EXISTS(SELECT * FROM sysobjects WHERE type IN ('FN', 'TF') AND name='org_num_of_running_contracts')
BEGIN
  DROP FUNCTION guest.org_num_of_running_contracts
END
GO

CREATE FUNCTION guest.org_num_of_running_contracts (@OrgID INT)

/*
Количество контрактов у заказчика, исполняемых на данный момент
*/

RETURNS FLOAT
AS
BEGIN
  DECLARE @num_of_all_finished_contracts FLOAT = (
    SELECT COUNT(cntr.ID)
    FROM DV.f_OOS_Value AS val
    INNER JOIN DV.d_OOS_Org AS org ON org.ID = val.RefOrg
    INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
    WHERE 
  		org.ID = @OrgID AND 
  		cntr.RefStage = 2
  )
  RETURN @num_of_all_finished_contracts
END
GO