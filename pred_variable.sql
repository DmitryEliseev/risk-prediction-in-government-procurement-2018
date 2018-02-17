CREATE FUNCTION pred_variable (@CntrID INT)

/*
Функция, которая определяет является ли контракт хорошим или плохим (предсказываемая величина).
Заверешнный контракт является хорошим, если
1) Причина разрыва контракта не указана ИЛИ
2) Разрыв по обоюдному соглашению и контракт выполнен на более 60%
В остальных случая контракт плохой.
*/

RETURNS INT
AS
BEGIN
  DECLARE @PredVar INT = (
    SELECT 'predicted_variable' =
      CASE
        WHEN 
          trmn.Code = 0 OR 
          (
            trmn.Code IN (8361024,8724080,1) AND 
            sum(clsCntr.FactPaid) / val.Price >= 0.6
          ) THEN 1
        ELSE 0
      END
    FROM f_OOS_Value as val
    INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
    INNER JOIN DV.d_OOS_ClosContracts AS clsCntr ON clsCntr.RefContract = cntr.ID
    INNER JOIN DV.d_OOS_TerminReason AS trmn ON trmn.ID = clsCntr.RefTerminReason
    WHERE cntr.ID = @CntrID
    GROUP BY cntr.ID, trmn.Code, val.Price
  )
  RETURN @PredVar
END