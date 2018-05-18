CREATE FUNCTION guest.sup_okpd_cntr_num (@SupID INT, @OkpdID INT)

/*
Количество завершенных контрактов для конкретного ОКПД и поставщика
*/

RETURNS INT
AS
BEGIN
  DECLARE @cur_okpd_contracts_num INT = (
    SELECT COUNT(*)
    FROM
    (
      SELECT DISTINCT cntr.ID
      FROM DV.f_OOS_Product AS prod
      INNER JOIN DV.d_OOS_Suppliers AS sup ON sup.ID = prod.RefSupplier
      INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = prod.RefContract
      INNER JOIN DV.d_OOS_Products AS prods ON prods.ID = prod.RefProduct
      WHERE 
        sup.ID = @SupID AND 
        cntr.RefStage in (3, 4) AND
		    prods.RefOKPD2 = @OkpdID
    )t
  ) 
  RETURN @cur_okpd_contracts_num
END