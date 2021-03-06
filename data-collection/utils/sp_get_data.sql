IF EXISTS(SELECT * FROM sysobjects WHERE type = 'P' AND name = 'sp_get_data')
BEGIN
  DROP PROCEDURE guest.sp_get_data
END
GO

CREATE PROCEDURE guest.sp_get_data(@RegNums VARCHAR(MAX))
/*
Функция, возвращающая выборку для построения предсказаний для контрактов по регистрационным номерам
*/
AS
BEGIN
  SELECT * 
  FROM guest.sample s 
  WHERE s.cntr_reg_num IN 
  (
    SELECT * FROM guest.fn_split_string(@RegNums, '.')
  )
END
GO
