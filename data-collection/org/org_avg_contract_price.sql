IF EXISTS(SELECT * FROM sysobjects WHERE type IN ('FN', 'TF') AND name='org_avg_contract_price')
BEGIN
  DROP FUNCTION guest.org_avg_contract_price
END
GO

CREATE FUNCTION guest.org_avg_contract_price (@OrgID INT)

/*
Средняя цена контракта заказчика
*/

RETURNS BIGINT
AS
BEGIN
  DECLARE @AvgPrice BIGINT = (
    SELECT AVG(val.Price)
    FROM DV.f_OOS_Value AS val
    INNER JOIN DV.d_OOS_Org AS org ON org.ID = val.RefOrg
    INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
    WHERE 
		org.ID = @OrgID AND 
		cntr.RefStage IN (3, 4)
  )
  RETURN @AvgPrice
END
GO