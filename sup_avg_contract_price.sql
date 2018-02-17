CREATE FUNCTION sup_avg_contract_price (@SupID INT)

/*
Средняя цена контракта заказчика
*/

RETURNS FLOAT
AS
BEGIN
  DECLARE @AvgPrice INT
  SET @AvgPrice = (
    SELECT AVG(val.Price)
    FROM f_OOS_Value AS val
    INNER JOIN DV.d_OOS_Suppliers AS sup ON sup.ID = val.RefSupplier
    INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
    INNER JOIN DV.fx_OOS_ContractStage AS cntrSt ON cntrSt.ID = cntr.RefStage
    WHERE sup.ID = @SupID AND cntrSt.ID IN (3, 4)
  )
  
  RETURN @AvgPrice
END