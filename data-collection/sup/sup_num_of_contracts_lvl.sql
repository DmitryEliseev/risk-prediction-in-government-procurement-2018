IF EXISTS(SELECT * FROM sysobjects WHERE type IN ('FN', 'TF') AND name='sup_num_of_contracts_lvl')
BEGIN
  DROP FUNCTION guest.sup_num_of_contracts_lvl
END
GO

CREATE FUNCTION guest.sup_num_of_contracts_lvl (@SupID INT, @Lvl INT)

/*
Количество завершенных контрактов по определенному уровню (федеральному, региональному, муниципальному) 
для конкретного поставщика
*/

RETURNS INT
AS
BEGIN
  DECLARE @num_of_contracts_lvl INT = (
    SELECT COUNT(cntr.ID)
  	FROM DV.f_OOS_Value AS val
    INNER JOIN DV.d_OOS_Suppliers AS sup ON sup.ID = val.RefSupplier
  	INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
  	WHERE
  		sup.ID = @SupID AND 
  		cntr.RefStage IN (3, 4) AND
  		val.RefLevelOrder = @Lvl
  )
  RETURN @num_of_contracts_lvl
END
GO