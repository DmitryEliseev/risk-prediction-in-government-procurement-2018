/*
Добавление в таблицу с выборкой следующих столбцов: 
- print_form - ссылка на печатную форму контракта,
- kbk - КБК контракта,
- publish_date - дата публикации извещения,
- purch - наименование способа закупки,
- grbs_code - код ГРБС,
- grbs_name - наименование ГРБС,
- sup_name - наименование поставщика,
- sup_INN - ИНН поставщика,
- sup_KPP - КПП поставщика
*/

ALTER TABLE guest.sample ADD print_form VARCHAR(100)
ALTER TABLE guest.sample ADD kbk VARCHAR(20)
ALTER TABLE guest.sample ADD publish_date INT
ALTER TABLE guest.sample ADD purch VARCHAR(350)

GO
UPDATE guest.sample
SET
  print_form = cntr.PrintForm,
  kbk = cntr.KBK,
  publish_date = cntr.RefPublishDate,
  purch = prch.Name
FROM guest.sample
INNER JOIN DV.d_OOS_Contracts cntr ON guest.sample.cntrID = cntr.ID
INNER JOIN DV.fx_OOS_TypePurch prch ON prch.ID = cntr.RefTypePurch
GO

ALTER TABLE guest.sample ADD grbs_code VARCHAR(15)
ALTER TABLE guest.sample ADD grbs_name VARCHAR(250)

GO
UPDATE guest.sample
SET
  grbs_code = grbs.PARENTUBPCODE,
  grbs_name = grbs.PARENTUBPNAME
FROM guest.sample
INNER JOIN DV.d_OOS_Org org ON guest.sample.orgID = org.ID
INNER JOIN DV.D_EB_RUBPNUBP grbs on org.INN = grbs.INN
GO

ALTER TABLE guest.sample ADD org_name VARCHAR(300)
GO
UPDATE guest.sample
SET
  org_name = org.ShortName
FROM guest.sample
INNER JOIN DV.d_OOS_Org org ON guest.sample.orgID = org.ID
GO

ALTER TABLE guest.sample ADD sup_name VARCHAR(200)
ALTER TABLE guest.sample ADD sup_INN VARCHAR(12)
ALTER TABLE guest.sample ADD sup_KPP VARCHAR(9)

GO
UPDATE guest.sample
SET
  sup_name = SUBSTRING(sup.Name, 1, 200),
  sup_INN = sup.INN,
  sup_KPP = sup.KPP
FROM guest.sample
INNER JOIN DV.d_OOS_Suppliers sup ON guest.sample.supID = sup.ID
GO