IF EXISTS(SELECT * FROM sysobjects WHERE type IN ('FN', 'TF') AND name='fn_split_string')
BEGIN
  DROP FUNCTION guest.fn_split_string
END
GO

CREATE FUNCTION guest.fn_split_string(@String VARCHAR(MAX), @Delimiter CHAR(1))

/*
Разбиение строки по разделителю
*/

RETURNS @Parts TABLE (part varchar(25))
AS
BEGIN
  DECLARE @Xml XML
  SET @Xml = CAST(('<X>'  +REPLACE(@String, @Delimiter, '</X><X>') + '</X>') AS XML)
  INSERT INTO @Parts SELECT C.value('.', 'varchar(19)') AS value FROM @Xml.nodes('X') AS X(C)
  RETURN
END
GO