/*
Предварительный подсчет необходимых для построения целевый выборки метрик 
и сохранение результатов в промежуточные таблицы
*/

DROP TABLE sup_stats
DROP TABLE org_stats
DROP TABLE okpd_stats
--DROP TABLE ter_stats
DROP TABLE okpd_sup_stats
DROP TABLE sup_org_stats

GO
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
    OkpdID INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
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
    OkpdCode INT NOT NULL,
    cntr_num INT,
    PRIMARY KEY (SupID, OkpdCode)
  )

--Создание таблицы для хранения статистики по взаимодейтсию поставщика и заказчика
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='sup_org_stats' AND xtype='U')
  CREATE TABLE guest.sup_org_stats (
    SupID INT NOT NULL,
    OrgID INT NOT NULL,
    cntr_num INT,
    PRIMARY KEY (SupID, OrgID)
  )
  
GO
--Заполнение таблицы со статистикой по поставщикам
INSERT INTO sup_stats 
SELECT
sup.ID,
guest.sup_num_of_contracts(sup.ID),
guest.sup_num_of_running_contracts(sup.ID),
guest.sup_num_of_good_contracts(sup.ID),
guest.sup_num_of_contracts_lvl(sup.ID, 1),
guest.sup_num_of_contracts_lvl(sup.ID, 2),
guest.sup_num_of_contracts_lvl(sup.ID, 3),
guest.sup_avg_contract_price(sup.ID),
guest.sup_avg_penalty_share(sup.ID),
guest.sup_no_penalty_cntr_share(sup.ID),
guest.sup_one_side_severance_share(sup.ID),
guest.sup_one_side_org_severance_share(sup.ID)
FROM DV.d_OOS_Suppliers AS sup

GO
--Заполнение таблицы со статистикой по заказчикам
INSERT INTO org_stats 
SELECT
org.ID,
guest.org_num_of_contracts(org.ID),
guest.org_num_of_running_contracts(org.ID),
guest.org_num_of_good_contracts(org.ID),
guest.org_num_of_contracts_lvl(org.ID, 1),
guest.org_num_of_contracts_lvl(org.ID, 2),
guest.org_num_of_contracts_lvl(org.ID, 3),
guest.org_avg_contract_price(org.ID),
guest.org_one_side_severance_share(org.ID),
guest.org_one_side_supplier_severance_share(org.ID)
FROM DV.d_OOS_Org AS org

GO
--Заполнение таблицы со статистикой по ОКПД: количество завершенных контрактов по ОКПД
INSERT INTO okpd_stats (okpd_stats.code, okpd_stats.cntr_num)
SELECT okpd.Code, COUNT(cntr.ID)
FROM 
DV.d_OOS_OKPD2 AS okpd 
INNER JOIN DV.d_OOS_Products AS prods ON prods.RefOKPD2 = okpd.ID
INNER JOIN DV.f_OOS_Product AS prod ON prod.RefProduct = prods.ID
INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = prod.RefContract
INNER JOIN DV.fx_OOS_ContractStage AS cntrSt ON cntrSt.ID = cntr.RefStage
WHERE cntrSt.ID IN (3, 4)
GROUP BY okpd.Code

--Заполнение таблицы со статистикой по ОКПД: количество хороших контрактов по ОКПД
UPDATE okpd_stats
SET okpd_stats.good_cntr_num = t.good_cntr_num
FROM
(
  SELECT okpd.code, COUNT(cntr.ID) AS 'good_cntr_num'
  FROM 
  DV.d_OOS_OKPD2 AS okpd 
  INNER JOIN DV.d_OOS_Products AS prods ON prods.RefOKPD2 = okpd.ID
  INNER JOIN DV.f_OOS_Product AS prod ON prod.RefProduct = prods.ID
  INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = prod.RefContract
  INNER JOIN DV.fx_OOS_ContractStage AS cntrSt ON cntrSt.ID = cntr.RefStage
  WHERE 
    guest.pred_variable(cntr.ID) = 1 AND
    cntrSt.ID IN (3, 4)
  GROUP BY okpd.Code
)t
WHERE t.code = okpd_stats.code

GO
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

GO
-- Заполнение таблицы okpd_sup_stats
INSERT INTO okpd_sup_stats
SELECT t.ID, t.Code, guest.sup_okpd_cntr_num(t.ID, t.Code)
FROM 
(
  SELECT DISTINCT sup.ID, okpd.Code
  FROM DV.f_OOS_Product AS prod
  INNER JOIN DV.d_OOS_Suppliers AS sup ON sup.ID = prod.RefSupplier
  INNER JOIN DV.d_OOS_Org AS org ON org.ID = prod.RefOrg
  INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = prod.RefContract
  INNER JOIN DV.fx_OOS_ContractStage AS cntrSt ON cntrSt.ID = cntr.RefStage
  INNER JOIN DV.d_OOS_Products AS prods ON prods.ID = prod.RefProduct
  INNER JOIN DV.d_OOS_OKPD2 AS okpd ON okpd.ID = prods.RefOKPD2
  WHERE cntrSt.ID in (3, 4)
)t

GO
-- Заполнение таблицы sup_org_stats
INSERT INTO sup_org_stats
SELECT DISTINCT sup.ID, org.ID, guest.sup_org_cntr_num(sup.ID, org.ID)
FROM DV.f_OOS_Value AS val
INNER JOIN DV.d_OOS_Suppliers AS sup ON sup.ID = val.RefSupplier
INNER JOIN DV.d_OOS_Org AS org ON org.ID = val.RefOrg
INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
INNER JOIN DV.d_OOS_ClosContracts As cntrCls ON cntrCls.RefContract = cntr.ID
INNER JOIN DV.fx_OOS_ContractStage AS cntrSt ON cntrSt.ID = cntr.RefStage
WHERE cntrSt.ID IN (3, 4)