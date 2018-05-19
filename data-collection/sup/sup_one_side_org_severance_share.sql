IF EXISTS(SELECT * FROM sysobjects WHERE type IN ('FN', 'TF') AND name='sup_one_side_org_severance_share')
BEGIN
  DROP FUNCTION guest.sup_one_side_org_severance_share
END
GO

CREATE FUNCTION guest.sup_one_side_org_severance_share (@SupID INT, @NumOfCntr INT)

/*
Репутация поставщика: доля контрактов с разрывом отношений в одностороннем порядке по решению заказчика.
Под разрывом в одностороннем порядке понимается:
- разрыв по решению заказчика в одностороннем порядке (код в БД: 8326974);
- решение заказчика об одностороннем отказе от исполнения контракта (код в БД: 8361022);
- односторонний отказ заказчика от исполнения контракта в соответствии с гражданским законодательством (код в БД: 8724082)
*/

RETURNS FLOAT
AS
BEGIN
  DECLARE @num_of_bad_contracts INT = (
  	SELECT COUNT(*)
  	FROM
  	(
  		SELECT DISTINCT cntr.ID
  		FROM DV.f_OOS_Value AS val
  		INNER JOIN DV.d_OOS_Suppliers AS sup ON sup.ID = val.RefSupplier
  		INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
  		INNER JOIN DV.d_OOS_ClosContracts As cntrCls ON cntrCls.RefContract = cntr.ID
  		INNER JOIN DV.d_OOS_TerminReason AS trmn ON trmn.ID = cntrCls.RefTerminReason
  		WHERE 
  			trmn.Code IN (8326974, 8361022, 8724082) AND 
  			sup.ID = @SupID
  	)t
  )
  
  IF @NumOfCntr = 0
  BEGIN
    RETURN 0
  END
  
  RETURN ROUND(@num_of_bad_contracts / @NumOfCntr, 3)
END
GO