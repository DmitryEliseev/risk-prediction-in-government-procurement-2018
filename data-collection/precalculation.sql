/*
Предварительный подсчет необходимых для построения целевый выборки метрик 
и сохранение результатов в промежуточные таблицы
*/

--Создание таблицы для хранения статистики по поставщикам
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='sup_stats' AND xtype='U')
  CREATE TABLE guest.sup_stats (
    SupID INT NOT NULL,
    sup_cntr_num INT,
    sup_running_cntr_num INT,
    sup_good_cntr_num INT,
    sup_fed_cntr_num INT,
    sup_sub_cntr_num INT,
    sup_mun_cntr_num INT,
    sup_cntr_avg_price BIGINT,
    sup_cntr_avg_penalty FLOAT,
    sup_no_pnl_share FLOAT,
    sup_1s_sev FLOAT,
    sup_1s_org_sev FLOAT
    PRIMARY KEY(SupID)
  )

--Создание таблицы для хранения статистики по заказчикам
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='org_stats' AND xtype='U')
  CREATE TABLE guest.org_stats (
    OrgID INT NOT NULL,
    org_cntr_num INT,
    org_running_cntr_num INT,
    org_good_cntr_num INT,
    org_fed_cntr_num INT,
    org_sub_cntr_num INT,
    org_mun_cntr_num INT,
    org_cntr_avg_price BIGINT,
    org_1s_sev INT,
    org_1s_sup_sev FLOAT,
    PRIMARY KEY(OrgID)
  )

--Создание таблицы для хранения статистики по ОКПД
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='okpd_stats' AND xtype='U')
  CREATE TABLE guest.okpd_stats (
    OkpdID INT NOT NULL PRIMARY KEY,
    code VARCHAR(9),
    cntr_num INT,
    good_cntr_num INT
  )

--Создание таблицы для хранения статистики по территории
--IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='ter_stats' AND xtype='U')
--  CREATE TABLE guest.ter_stats (
--    TerrID INT NOT NULL PRIMARY KEY,
--    cntr_num INT,
--    good_cntr_num INT
--  )

--Создание таблицы для хранения статистики по ОКПД и поставщику
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='okpd_sup_stats' AND xtype='U')
  CREATE TABLE guest.okpd_sup_stats (
    SupID INT NOT NULL,
    OkpdID INT NOT NULL,
    cntr_num INT,
    PRIMARY KEY (SupID, OkpdID)
  )

--Создание таблицы для хранения статистики по взаимодейтсию поставщика и заказчика
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='sup_org_stats' AND xtype='U')
  CREATE TABLE guest.sup_org_stats (
    SupID INT NOT NULL,
    OrgID INT NOT NULL,
    cntr_num INT,
    PRIMARY KEY (SupID, OrgID)
  )
  
  --Таблица для статистики по контрактам
  IF NOT EXISTS (SELECT * FROM sysobjects WHERE name = 'cntr_stats' AND xtype='U')
    CREATE TABLE guest.cntr_stats (
      CntrID INT NOT NULL PRIMARY KEY,
      result BIT
    )
GO

--I: Заполнение таблицы со статистикой по поставщикам
INSERT INTO sup_stats (
  SupID, sup_cntr_num, sup_running_cntr_num, sup_good_cntr_num, 
  sup_fed_cntr_num, sup_sub_cntr_num, sup_mun_cntr_num, 
  sup_cntr_avg_price, sup_cntr_avg_penalty
)
SELECT
sup.ID,
guest.sup_num_of_contracts(sup.ID),
guest.sup_num_of_running_contracts(sup.ID),
guest.sup_num_of_good_contracts(sup.ID),
guest.sup_num_of_contracts_lvl(sup.ID, 1),
guest.sup_num_of_contracts_lvl(sup.ID, 2),
guest.sup_num_of_contracts_lvl(sup.ID, 3),
guest.sup_avg_contract_price(sup.ID),
guest.sup_avg_penalty_share(sup.ID)
FROM DV.d_OOS_Suppliers AS sup
--II: Заполнение таблицы со статистикой по поставщикам
UPDATE sup_stats
SET 
  sup_no_pnl_share = guest.sup_no_penalty_cntr_share(supID, sup_cntr_num),
  sup_1s_sev = guest.sup_one_side_severance_share(supID, sup_cntr_num),
  sup_1s_org_sev = guest.sup_one_side_org_severance_share(supID, sup_cntr_num)
GO -- 5.7 млн строк за 12ч20мин

--I: Заполнение таблицы со статистикой по заказчикам
INSERT INTO org_stats (
  OrgID, org_cntr_num, org_running_cntr_num, org_good_cntr_num,
  org_fed_cntr_num, org_sub_cntr_num, org_mun_cntr_num, org_cntr_avg_price
)
SELECT
org.ID,
guest.org_num_of_contracts(org.ID),
guest.org_num_of_running_contracts(org.ID),
guest.org_num_of_good_contracts(org.ID),
guest.org_num_of_contracts_lvl(org.ID, 1),
guest.org_num_of_contracts_lvl(org.ID, 2),
guest.org_num_of_contracts_lvl(org.ID, 3),
guest.org_avg_contract_price(org.ID)
FROM DV.d_OOS_Org AS org
--II: Заполнение таблицы со статистикой по заказчикам
UPDATE org_stats
SET
  org_1s_sev = guest.org_one_side_severance_share(orgID, org_cntr_num),
  org_1s_sup_sev = guest.org_one_side_supplier_severance_share(orgID, org_cntr_num)
GO --300 тыс. строк за 10ч

--I: Заполнение таблицы со статистикой по ОКПД: количество завершенных контрактов по ОКПД
INSERT INTO okpd_stats (okpd_stats.OkpdID, okpd_stats.code, okpd_stats.cntr_num)
SELECT okpd.ID, okpd.Code, COUNT(cntr.ID)
FROM 
DV.d_OOS_OKPD2 AS okpd 
INNER JOIN DV.d_OOS_Products AS prods ON prods.RefOKPD2 = okpd.ID
INNER JOIN DV.f_OOS_Product AS prod ON prod.RefProduct = prods.ID
INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = prod.RefContract
WHERE cntr.RefStage IN (3, 4)
GROUP BY okpd.ID, okpd.Code
--II: Заполнение таблицы со статистикой по ОКПД: количество хороших контрактов по ОКПД
UPDATE okpd_stats
SET okpd_stats.good_cntr_num = t.good_cntr_num
FROM
(
  SELECT okpd.ID AS OkpdID, COUNT(cntr.ID) AS 'good_cntr_num'
  FROM 
  DV.d_OOS_OKPD2 AS okpd 
  INNER JOIN DV.d_OOS_Products AS prods ON prods.RefOKPD2 = okpd.ID
  INNER JOIN DV.f_OOS_Product AS prod ON prod.RefProduct = prods.ID
  INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = prod.RefContract
  WHERE 
    guest.pred_variable(cntr.ID) = 1 AND
    cntr.RefStage IN (3, 4)
  GROUP BY okpd.ID
)t
WHERE t.OkpdID = okpd_stats.OkpdID
GO --19 тыс. строк за 2ч40мин

--Заполнение таблицы со статистикой по территориям
--INSERT INTO ter_stats 
--SELECT 
--t.Code1,
--guest.ter_num_of_contracts(t.Code1),
--guest.ter_num_of_good_contracts(t.Code1)
--FROM
--(
--  SELECT DISTINCT
--  ter.Code1
--  FROM DV.d_Territory_RF AS ter
--)t
--GO

-- Заполнение таблицы okpd_sup_stats
INSERT INTO okpd_sup_stats
SELECT t.SupID, t.OkpdID, guest.sup_okpd_cntr_num(t.SupID, t.okpdID)
FROM 
(
  SELECT sup.ID AS SupID, prods.RefOKPD2 AS okpdID
  FROM DV.f_OOS_Product AS prod
  INNER JOIN DV.d_OOS_Suppliers AS sup ON sup.ID = prod.RefSupplier
  INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = prod.RefContract
  INNER JOIN DV.d_OOS_Products AS prods ON prods.ID = prod.RefProduct
  WHERE cntr.RefStage in (3, 4)
  GROUP BY sup.ID, prods.RefOKPD2
)t
GO --5.1 млн строк за 16ч24мин

-- Заполнение таблицы sup_org_stats
INSERT INTO sup_org_stats
SELECT t.supID, t.orgID, guest.sup_org_cntr_num(t.supID, t.orgID)
FROM
(
  SELECT sup.ID AS SupID, org.ID AS OrgID
  FROM DV.f_OOS_Value AS val
  INNER JOIN DV.d_OOS_Suppliers AS sup ON sup.ID = val.RefSupplier
  INNER JOIN DV.d_OOS_Org AS org ON org.ID = val.RefOrg
  INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
  WHERE cntr.RefStage IN (3, 4)
  GROUP BY sup.ID, org.ID
)t
GO --6.2 млн строк за 10ч15мин

--Заполнение таблицы cntr_stats результатами исполнения контрактов
INSERT INTO guest.cntr_stats
SELECT t.cntrID, guest.pred_variable(t.cntrID)
FROM
(
  SELECT DISTINCT cntr.ID AS cntrID
  FROM DV.d_OOS_Contracts cntr
  WHERE cntr.RefSignDate > 20150000 AND cntr.RefStage IN (3, 4)
)t
GO --5.3 млн за 1ч10мин