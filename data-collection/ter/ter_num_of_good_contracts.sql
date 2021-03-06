IF EXISTS(SELECT * FROM sysobjects WHERE type IN ('FN', 'TF') AND name='ter_num_of_good_contracts')
BEGIN
  DROP FUNCTION guest.ter_num_of_good_contracts
END
GO

CREATE FUNCTION guest.ter_num_of_good_contracts (@TerrCode INT)

/*
Количество "хороших" завершенных контрактов в рамках определенной территории
*/

RETURNS INT
AS
BEGIN
  DECLARE @num_of_contracts INT = (
    SELECT COUNT(*)
    FROM
    (
      SELECT cntr.ID
  		FROM DV.f_OOS_Value AS val
      INNER JOIN DV.d_Territory_RF AS ter ON ter.ID = val.RefTerritory
  		INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
      WHERE
        ter.Code1 = @TerrCode AND
    	  cntr.RefStage IN (3, 4) AND
        guest.pred_variable(cntr.ID) = 1
    )t 
  )
  RETURN @num_of_contracts
END
GO