CREATE FUNCTION guest.sup_avg_contract_price (@SupID INT)

/*
Средняя цена контракта поставщика
*/

RETURNS BIGINT
AS
BEGIN
  DECLARE @AvgPrice BIGINT = (
    SELECT AVG(val.Price)
    FROM DV.f_OOS_Value AS val
    INNER JOIN DV.d_OOS_Suppliers AS sup ON sup.ID = val.RefSupplier
    INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
    WHERE 
		  sup.ID = @SupID AND 
		  cntr.RefStage IN (3, 4)
  )
  RETURN @AvgPrice
END