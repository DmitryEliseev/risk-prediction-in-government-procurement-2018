IF EXISTS(SELECT * FROM sysobjects WHERE type IN ('FN', 'TF') AND name='org_similar_contracts_by_price_share')
BEGIN
  DROP FUNCTION guest.org_similar_contracts_by_price_share
END
GO

CREATE FUNCTION guest.org_similar_contracts_by_price_share (@OrgID INT, @NumOfCntr INT, @CntrPrice BIGINT)

/*
Количество завершенных заказов у заказчика, цена которых отличается от цены текущего контракте не более, чем на 20%
*/

RETURNS FLOAT
AS
BEGIN
  DECLARE @num_of_similar_contracts_by_price FLOAT = (
	SELECT COUNT(cntr.ID)
  	FROM DV.f_OOS_Value AS val
  	INNER JOIN DV.d_OOS_Org AS org ON org.ID = val.RefOrg
  	INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
  	WHERE 
		  org.ID = @OrgID AND 
  		cntr.RefStage IN (3, 4) AND 
  		ABS(val.Price - @CntrPrice) <= 0.2*@CntrPrice
  )
  
  -- Обработка случая, когда у заказчика еще нет ни одного завершенного контракта
  -- Такое теоретически невозможно, но на практике встречается
  IF @NumOfCntr = 0
  BEGIN
    RETURN 0
  END
  
  RETURN ROUND(@num_of_similar_contracts_by_price / @NumOfCntr, 3)
END
GO