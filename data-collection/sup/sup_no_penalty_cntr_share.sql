IF EXISTS(SELECT * FROM sysobjects WHERE type IN ('FN', 'TF') AND name='sup_no_penalty_cntr_share')
BEGIN
  DROP FUNCTION guest.sup_no_penalty_cntr_share
END
GO

CREATE FUNCTION guest.sup_no_penalty_cntr_share (@SupID INT, @NumOfCntr INT)

/*
Доля контрактов без пени от общего числе завершенных поставщиком контрактов
*/

RETURNS FLOAT
AS
BEGIN
  DECLARE @no_penalty_cntr_num INT = (
    SELECT COUNT(*)
    FROM
    (
      SELECT DISTINCT cntr.ID
  		FROM DV.f_OOS_Value AS val
      INNER JOIN DV.d_OOS_Suppliers AS sup ON sup.ID = val.RefSupplier
  		INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
      LEFT JOIN DV.d_OOS_Penalties AS pnl ON pnl.RefContract = cntr.ID
      WHERE
        sup.ID = @SupID AND 
    	  cntr.RefStage IN (3, 4) AND
        pnl.Accrual IS NULL
    )t 
  )
  
  -- Обработка случая, когда у поставщика еще нет ни одного завершенного контракта
  IF @NumOfCntr = 0
  BEGIN
    RETURN 0
  END
  
  RETURN ROUND(@no_penalty_cntr_num / @NumOfCntr, 3)
END
GO