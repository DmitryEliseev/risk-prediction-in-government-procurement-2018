CREATE FUNCTION guest.org_one_side_supplier_severance_share (@OrgID INT, @NumOfCntr INT)

/*
Репутация заказчика: доля контрактов с разрывом отношений в одностороннем порядке по решению поставшика.
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
  		INNER JOIN DV.d_OOS_Org AS org ON org.ID = val.RefOrg
  		INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
  		INNER JOIN DV.d_OOS_ClosContracts As cntrCls ON cntrCls.RefContract = cntr.ID
  		INNER JOIN DV.d_OOS_TerminReason AS trmn ON trmn.ID = cntrCls.RefTerminReason
  		WHERE 
  			trmn.Code IN (8326975, 8361023, 8724083) AND 
  			org.ID = @OrgID
  	)t
  )
  
   -- Обработка случая, когда у заказщика нет завершенных контрактов
  IF @NumOfCntr = 0
  BEGIN
    RETURN 0
  END
  
  RETURN ROUND(@num_of_bad_contracts / @NumOfCntr, 3)
END