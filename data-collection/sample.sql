/*
Сбор обучающей выборки
*/

--Создание таблицы для хранения выборки
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='sample' AND xtype='U')
  CREATE TABLE guest.sample (
    valID INT NOT NULL,
    cntrID INT NOT NULL,
    supID INT NOT NULL,
    orgID INT NOT NULL,
    okpdID INT NOT NULL,
    cntr_reg_num VARCHAR(19),
    
    --Поставщик
    sup_cntr_num INT,
    sup_running_cntr_num INT,
    sup_good_cntr_num FLOAT,
    sup_fed_cntr_num FLOAT, 
    sup_sub_cntr_num FLOAT, 
    sup_mun_cntr_num FLOAT,
    sup_cntr_avg_price BIGINT,
    sup_cntr_avg_penalty_share FLOAT,
    sup_no_pnl_share FLOAT,
    sup_1s_sev FLOAT,
    sup_1s_org_sev FLOAT,
    sup_okpd_cntr_num INT,
    sup_sim_price_share FLOAT,
    
    --Заказчик
    org_cntr_num INT,
    org_running_cntr_num INT,
    org_good_cntr_num FLOAT,
    org_fed_cntr_num FLOAT,
    org_sub_cntr_num FLOAT,
    org_mun_cntr_num FLOAT,
    org_cntr_avg_price BIGINT,
    org_1s_sev FLOAT,
    org_1s_sup_sev FLOAT,
    org_sim_price_share FLOAT,
    cntr_num_together INT,
    org_type INT,
    
    --ОКПД
    okpd_cntr_num INT,
    okpd_good_cntr_num INT,
    okpd VARCHAR(9),

    --Контракт
    price BIGINT,
    pmp BIGINT,
    cntr_lvl INT,
    sign_date INT,
    exec_date INT,
    purch_type INT,
    price_higher_pmp BIT,
    price_too_low BIT,

    --Целевая переменная
    cntr_result BIT,
    
     --Составной первичный ключ
    PRIMARY KEY (valID, cntrID, supID, orgID, okpdID)
  )
GO

--Если будет попытка вставить запись, нарушающую уникальность первичного ключа,
--то данная попытка будет проигнорирована
ALTER TABLE guest.sample REBUILD WITH (IGNORE_DUP_KEY = ON)
GO

--Заполнение плохими контрактами
INSERT INTO guest.sample
SELECT
val.ID, 
cntr.ID,
val.RefSupplier,
org.ID,
okpd.ID,
cntr.RegNum,

--Поставщик
guest.sup_stats.sup_cntr_num,
guest.sup_stats.sup_running_cntr_num,
guest.sup_stats.sup_good_cntr_num AS 'sup_good_cntr_num',
guest.sup_stats.sup_fed_cntr_num AS 'sup_fed_cntr_num',
guest.sup_stats.sup_sub_cntr_num AS 'sup_sub_cntr_num',
guest.sup_stats.sup_mun_cntr_num AS 'sup_mun_cntr_num',
guest.sup_stats.sup_cntr_avg_price,
guest.sup_stats.sup_cntr_avg_penalty,
guest.sup_stats.sup_no_pnl_share,
guest.sup_stats.sup_1s_sev,
guest.sup_stats.sup_1s_org_sev,
guest.okpd_sup_stats.cntr_num AS 'sup_okpd_cntr_num',
NULL, --Вычисление позже

--Заказчик
guest.org_stats.org_cntr_num,
guest.org_stats.org_running_cntr_num,
guest.org_stats.org_good_cntr_num AS 'org_good_cntr_num',
guest.org_stats.org_fed_cntr_num AS 'org_fed_cntr_num',
guest.org_stats.org_sub_cntr_num AS 'org_sub_cntr_num',
guest.org_stats.org_mun_cntr_num AS 'org_mun_cntr_num',
guest.org_stats.org_cntr_avg_price,
guest.org_stats.org_1s_sev,
guest.org_stats.org_1s_sup_sev,
NULL, --Вычисление позже
guest.sup_org_stats.cntr_num AS 'cntr_num_together',
org.RefTypeOrg AS 'org_type',

--ОКПД
guest.okpd_stats.good_cntr_num as 'okpd_good_cntr_num',
guest.okpd_stats.cntr_num AS 'okpd_cntr_num',
okpd.Code AS 'okpd', 

--Контракт
val.Price AS 'price',
val.PMP AS 'pmp',
val.RefLevelOrder AS 'cntr_lvl',
cntr.RefSignDate AS 'sign_date',
cntr.RefExecution AS 'exec_date',
cntr.RefTypePurch AS 'purch_type',
CASE WHEN (val.PMP > 0) AND (val.Price > val.PMP) THEN 1 ELSE 0 END AS 'price_higher_pmp',
CASE WHEN val.Price <= val.PMP * 0.6 THEN 1 ELSE 0 END AS 'price_too_low',

--Целевая переменная
guest.cntr_stats.result AS 'cntr_result'

FROM DV.f_OOS_Value AS val
INNER JOIN DV.d_OOS_Org AS org ON org.ID = val.RefOrg
INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
INNER JOIN DV.f_OOS_Product AS prod ON prod.RefContract = cntr.ID
INNER JOIN DV.d_OOS_Products AS prods ON prods.ID = prod.RefProduct
INNER JOIN DV.d_OOS_OKPD2 AS okpd ON okpd.ID = prods.RefOKPD2
INNER JOIN guest.sup_stats ON val.RefSupplier = guest.sup_stats.SupID
INNER JOIN guest.org_stats ON org.ID = guest.org_stats.OrgID
INNER JOIN guest.okpd_stats ON okpd.ID = guest.okpd_stats.OkpdID
INNER JOIN guest.okpd_sup_stats ON (guest.okpd_sup_stats.SupID = val.RefSupplier AND guest.okpd_sup_stats.OkpdID = okpd.ID)
INNER JOIN guest.sup_org_stats ON (guest.sup_org_stats.SupID = val.RefSupplier AND guest.sup_org_stats.OrgID = org.ID)
INNER JOIN guest.cntr_stats ON guest.cntr_stats.CntrID = cntr.ID
WHERE
  val.RefLevelOrder = 1 AND --Контракт федерального уровня
  val.Price > 0 AND --Контракт реальный
  cntr.RefTypePurch != 6 AND --Не закупка у единственного поставщика
  cntr.RefStage IN (3, 4) AND --Контракт завершен
  cntr.RefSignDate > 20150000 AND --Контракт заключен не ранее 2015 года
  guest.org_stats.org_cntr_num > 0 AND --Количество контрактов у организации больше 0
  guest.sup_stats.sup_cntr_num > 0 AND --Количество контрактов у поставщика больше 0
  cntr_stats.result = 0 --Контракт плохой
GO

--Заполнение хорошими контрактами
INSERT INTO guest.sample
SELECT TOP(CAST(@@ROWCOUNT*1.5 AS INT))
val.ID, 
cntr.ID,
val.RefSupplier,
org.ID,
okpd.ID,
cntr.RegNum,

--Поставщик
guest.sup_stats.sup_cntr_num,
guest.sup_stats.sup_running_cntr_num,
guest.sup_stats.sup_good_cntr_num AS 'sup_good_cntr_num',
guest.sup_stats.sup_fed_cntr_num AS 'sup_fed_cntr_num',
guest.sup_stats.sup_sub_cntr_num AS 'sup_sub_cntr_num',
guest.sup_stats.sup_mun_cntr_num AS 'sup_mun_cntr_num',
guest.sup_stats.sup_cntr_avg_price,
guest.sup_stats.sup_cntr_avg_penalty,
guest.sup_stats.sup_no_pnl_share,
guest.sup_stats.sup_1s_sev,
guest.sup_stats.sup_1s_org_sev,
guest.okpd_sup_stats.cntr_num AS 'sup_okpd_cntr_num',
NULL,

--Заказчик
guest.org_stats.org_cntr_num,
guest.org_stats.org_running_cntr_num,
guest.org_stats.org_good_cntr_num AS 'org_good_cntr_num',
guest.org_stats.org_fed_cntr_num AS 'org_fed_cntr_num',
guest.org_stats.org_sub_cntr_num AS 'org_sub_cntr_num',
guest.org_stats.org_mun_cntr_num AS 'org_mun_cntr_num',
guest.org_stats.org_cntr_avg_price,
guest.org_stats.org_1s_sev,
guest.org_stats.org_1s_sup_sev,
NULL,
guest.sup_org_stats.cntr_num AS 'cntr_num_together',
org.RefTypeOrg AS 'org_type',

--ОКПД
guest.okpd_stats.good_cntr_num as 'okpd_good_cntr_num',
guest.okpd_stats.cntr_num AS 'okpd_cntr_num',
okpd.Code AS 'okpd', 

--Контракт
val.Price AS 'price',
val.PMP AS 'pmp',
val.RefLevelOrder AS 'cntr_lvl',
cntr.RefSignDate AS 'sign_date',
cntr.RefExecution AS 'exec_date',
cntr.RefTypePurch AS 'purch_type',
CASE WHEN (val.PMP > 0) AND (val.Price > val.PMP) THEN 1 ELSE 0 END AS 'price_higher_pmp',
CASE WHEN val.Price <= val.PMP * 0.6 THEN 1 ELSE 0 END AS 'price_too_low',

--Целевая переменная
guest.cntr_stats.result AS 'cntr_result'

FROM DV.f_OOS_Value AS val
INNER JOIN DV.d_OOS_Org AS org ON org.ID = val.RefOrg
INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
INNER JOIN DV.f_OOS_Product AS prod ON prod.RefContract = cntr.ID
INNER JOIN DV.d_OOS_Products AS prods ON prods.ID = prod.RefProduct
INNER JOIN DV.d_OOS_OKPD2 AS okpd ON okpd.ID = prods.RefOKPD2
INNER JOIN guest.sup_stats ON val.RefSupplier = guest.sup_stats.SupID
INNER JOIN guest.org_stats ON org.ID = guest.org_stats.OrgID
INNER JOIN guest.okpd_stats ON okpd.ID = guest.okpd_stats.OkpdID
INNER JOIN guest.okpd_sup_stats ON (guest.okpd_sup_stats.SupID = val.RefSupplier AND guest.okpd_sup_stats.OkpdID = okpd.ID)
INNER JOIN guest.sup_org_stats ON (guest.sup_org_stats.SupID = val.RefSupplier AND guest.sup_org_stats.OrgID = org.ID)
INNER JOIN guest.cntr_stats ON guest.cntr_stats.CntrID = cntr.ID
WHERE
  val.RefLevelOrder = 1 AND --Контракт федерального уровня
  val.Price > 0 AND --Контракт реальный
  cntr.RefTypePurch != 6 AND --Не закупка у единственного поставщика
  cntr.RefStage IN (3, 4) AND --Контракт завершен
  cntr.RefSignDate > 20150000 AND --Контракт заключен не ранее 2015 года
  guest.org_stats.org_cntr_num > 0 AND --Количество контрактов у организации больше 0
  guest.sup_stats.sup_cntr_num > 0 AND --Количество контрактов у поставщика больше 0
  guest.cntr_stats.result = 1 --Контракт хороший
ORDER BY NEWID()
GO

--Заполнение незавершенными контрактами
INSERT INTO guest.sample
SELECT
val.ID, 
cntr.ID,
val.RefSupplier,
org.ID,
okpd.ID,
cntr.RegNum,

--Поставщик
guest.sup_stats.sup_cntr_num,
guest.sup_stats.sup_running_cntr_num,
guest.sup_stats.sup_good_cntr_num AS 'sup_good_cntr_num',
guest.sup_stats.sup_fed_cntr_num AS 'sup_fed_cntr_num',
guest.sup_stats.sup_sub_cntr_num AS 'sup_sub_cntr_num',
guest.sup_stats.sup_mun_cntr_num AS 'sup_mun_cntr_num',
guest.sup_stats.sup_cntr_avg_price,
guest.sup_stats.sup_cntr_avg_penalty,
guest.sup_stats.sup_no_pnl_share,
guest.sup_stats.sup_1s_sev,
guest.sup_stats.sup_1s_org_sev,
guest.okpd_sup_stats.cntr_num AS 'sup_okpd_cntr_num',
NULL,

--Заказчик
guest.org_stats.org_cntr_num,
guest.org_stats.org_running_cntr_num,
guest.org_stats.org_good_cntr_num AS 'org_good_cntr_num',
guest.org_stats.org_fed_cntr_num AS 'org_fed_cntr_num',
guest.org_stats.org_sub_cntr_num AS 'org_sub_cntr_num',
guest.org_stats.org_mun_cntr_num AS 'org_mun_cntr_num',
guest.org_stats.org_cntr_avg_price,
guest.org_stats.org_1s_sev,
guest.org_stats.org_1s_sup_sev,
NULL,
guest.sup_org_stats.cntr_num AS 'cntr_num_together',
org.RefTypeOrg AS 'org_type',

--ОКПД
guest.okpd_stats.good_cntr_num as 'okpd_good_cntr_num',
guest.okpd_stats.cntr_num AS 'okpd_cntr_num',
okpd.Code AS 'okpd', 

--Контракт
val.Price AS 'price',
val.PMP AS 'pmp',
val.RefLevelOrder AS 'cntr_lvl',
cntr.RefSignDate AS 'sign_date',
cntr.RefExecution AS 'exec_date',
cntr.RefTypePurch AS 'purch_type',
CASE WHEN (val.PMP > 0) AND (val.Price > val.PMP) THEN 1 ELSE 0 END AS 'price_higher_pmp',
CASE WHEN val.Price <= val.PMP * 0.6 THEN 1 ELSE 0 END AS 'price_too_low',

--Целевая переменная
NULL

FROM DV.f_OOS_Value AS val
INNER JOIN DV.d_OOS_Org AS org ON org.ID = val.RefOrg
INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
INNER JOIN DV.f_OOS_Product AS prod ON prod.RefContract = cntr.ID
INNER JOIN DV.d_OOS_Products AS prods ON prods.ID = prod.RefProduct
INNER JOIN DV.d_OOS_OKPD2 AS okpd ON okpd.ID = prods.RefOKPD2
INNER JOIN guest.sup_stats ON val.RefSupplier = guest.sup_stats.SupID
INNER JOIN guest.org_stats ON org.ID = guest.org_stats.OrgID
INNER JOIN guest.okpd_stats ON okpd.ID = guest.okpd_stats.OkpdID
INNER JOIN guest.okpd_sup_stats ON (guest.okpd_sup_stats.SupID = val.RefSupplier AND guest.okpd_sup_stats.OkpdID = okpd.ID)
INNER JOIN guest.sup_org_stats ON (guest.sup_org_stats.SupID = val.RefSupplier AND guest.sup_org_stats.OrgID = org.ID)
WHERE
  val.RefLevelOrder = 1 AND --Контракт федерального уровня
  val.Price > 0 AND --Контракт реальный
  cntr.RefTypePurch != 6 AND --Не закупка у единственного поставщика
  cntr.RefStage = 2 AND --Контракт исполняется
  cntr.RefSignDate > 20150000 AND --Контракт заключен не ранее 2015 года
  guest.org_stats.org_cntr_num > 0 AND --Количество контрактов у организации больше 0
  guest.sup_stats.sup_cntr_num > 0 --Количество контрактов у поставщика больше 0
GO

--Вычисление пропущенных переменных
UPDATE guest.sample
SET sup_sim_price_share = guest.sup_similar_contracts_by_price_share(val.RefSupplier, ss.sup_cntr_num, val.Price),
    org_sim_price_share = guest.org_similar_contracts_by_price_share(val.RefOrg, os.org_cntr_num, val.Price)
FROM guest.sample s
INNER JOIN DV.f_OOS_Value val ON s.valID = val.ID
INNER JOIN guest.sup_stats ss ON ss.SupID = val.RefSupplier
INNER JOIN guest.org_stats os ON os.OrgID = val.RefOrg
GO --72 тыс. строк за 1ч22мин