/*
Построение финальной выборки
*/

--Создание таблицы для хранения выборки
GO
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='sample' AND xtype='U')
  CREATE TABLE guest.sample (
    ID INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    valID INT NOT NULL,
    cntrID INT NOT NULL,
    supID INT NOT NULL,
    orgID INT NOT NULL,
    
    --Поставщик
    sup_cntr_num INT,
    sup_running_cntr_num INT,
    sup_good_cntr_share FLOAT,
    sup_fed_cntr_share FLOAT, 
    sup_sub_cntr_share FLOAT, 
    sup_mun_cntr_share FLOAT,
    sup_cntr_avg_price BIGINT,
    sup_cntr_avg_penalty_share FLOAT,
    sup_no_pnl_share FLOAT,
    sup_1s_sev FLOAT,
    sup_1s_org_sev FLOAT,
    sup_okpd_cntr_num INT,
    sup_sim_price_share FLOAT,
    sup_status INT,
    sup_type INT,
    
    --Заказчик
    org_cntr_num INT,
    org_running_cntr_num INT,
    org_good_cntr_share FLOAT,
    org_fed_cntr_share FLOAT,
    org_sub_cntr_share FLOAT,
    org_mun_cntr_share FLOAT,
    org_cntr_avg_price BIGINT,
    org_1s_sev FLOAT,
    org_1s_sup_sev FLOAT,
    org_sim_price_share FLOAT,
    cntr_num_together INT,
    org_form INT,
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
    cntr_result BIT

  )

--Заполнение плохими контрактами
GO
INSERT INTO guest.sample
SELECT
val.ID, 
cntr.ID,
sup.ID,
org.ID,

--Поставщик
guest.sup_stats.sup_cntr_num,
guest.sup_stats.sup_running_cntr_num,
ROUND(1.0 * guest.sup_stats.sup_good_cntr_num / guest.sup_stats.sup_cntr_num, 3) AS 'sup_good_cntr_share',
ROUND(1.0 * guest.sup_stats.sup_fed_cntr_num / guest.sup_stats.sup_cntr_num, 3) AS 'sup_fed_cntr_share',
ROUND(1.0 * guest.sup_stats.sup_sub_cntr_num / guest.sup_stats.sup_cntr_num, 3) AS 'sup_sub_cntr_share',
ROUND(1.0 * guest.sup_stats.sup_mun_cntr_num / guest.sup_stats.sup_cntr_num, 3) AS 'sup_mun_cntr_share',
guest.sup_stats.sup_cntr_avg_price,
guest.sup_stats.sup_cntr_avg_penalty,
guest.sup_stats.sup_no_pnl_share,
guest.sup_stats.sup_1s_sev,
guest.sup_stats.sup_1s_org_sev,
guest.okpd_sup_stats.cntr_num AS 'sup_okpd_cntr_num',
guest.sup_similar_contracts_by_price_share(sup.ID, val.Price) AS 'sup_sim_price_share',
sup.RefStatusSup AS 'sup_status',
supType.Code AS 'sup_type',

--Заказчик
guest.org_stats.org_cntr_num,
guest.org_stats.org_running_cntr_num,
ROUND(1.0 * guest.org_stats.org_good_cntr_num / guest.org_stats.org_cntr_num, 3) AS 'org_good_cntr_share',
ROUND(1.0 * guest.org_stats.org_fed_cntr_num / guest.org_stats.org_cntr_num, 3) AS 'org_fed_cntr_share',
ROUND(1.0 * guest.org_stats.org_sub_cntr_num / guest.org_stats.org_cntr_num, 3) AS 'org_sub_cntr_share',
ROUND(1.0 * guest.org_stats.org_mun_cntr_num / guest.org_stats.org_cntr_num, 3) AS 'org_mun_cntr_share',
guest.org_stats.org_cntr_avg_price,
guest.org_stats.org_1s_sev,
guest.org_stats.org_1s_sup_sev,
guest.org_similar_contracts_by_price_share(org.ID, val.Price) AS 'org_sim_price_share',
guest.sup_org_stats.cntr_num AS 'cntr_num_together',
orgForm.code AS org_form,
org.RefTypeOrg AS org_type,

--ОКПД
guest.okpd_stats.good_cntr_num as 'okpd_good_cntr_num',
guest.okpd_stats.cntr_num AS 'okpd_cntr_num',
okpd.Code AS okpd, 

--Контракт
val.Price AS price,
val.PMP AS pmp,
val.RefLevelOrder AS cntr_lvl,
cntr.RefSignDate AS sign_date,
cntr.RefExecution AS exec_date,
cntr.RefTypePurch AS purch_type,
CASE WHEN (val.PMP > 0) AND (val.Price > val.PMP) THEN 1 ELSE 0 END AS price_higher_pmp,
CASE WHEN val.Price <= val.PMP * 0.6 THEN 1 ELSE 0 END AS price_too_low,

--Целевая переменная
guest.pred_variable(cntr.ID) AS cntr_result

FROM DV.f_OOS_Value AS val
INNER JOIN DV.d_OOS_Suppliers AS sup ON sup.ID = val.RefSupplier
INNER JOIN DV.d_OOS_Org AS org ON org.ID = val.RefOrg
INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
INNER JOIN DV.d_Territory_RF AS ter ON ter.ID = val.RefTerritory
INNER JOIN DV.f_OOS_Product AS prod ON prod.RefContract = cntr.ID
INNER JOIN DV.d_OOS_Products AS prods ON prods.ID = prod.RefProduct
INNER JOIN DV.d_OOS_OKPD2 AS okpd ON okpd.ID = prods.RefOKPD2
INNER JOIN DV.fx_OOS_PartType AS supType ON supType.ID = sup.RefPartType
INNER JOIN DV.fx_OOS_OrgForm AS orgForm ON orgForm.ID = sup.RefFormOrg
INNER JOIN guest.sup_stats ON sup.ID = guest.sup_stats.SupID
INNER JOIN guest.org_stats ON org.ID = guest.org_stats.OrgID
INNER JOIN guest.okpd_stats ON okpd.Code = guest.okpd_stats.code
INNER JOIN guest.ter_stats ON ter.Code1 = ter_stats.TerrID
INNER JOIN guest.okpd_sup_stats ON (okpd_sup_stats.SupID = sup.ID AND okpd_sup_stats.OkpdCode = okpd.Code)
INNER JOIN guest.sup_org_stats ON (sup_org_stats.SupID = sup.ID AND sup_org_stats.OrgID = org.ID)
WHERE 
  guest.pred_variable(cntr.ID) = 0 AND
  val.Price > 0 AND --Контракт реальный
  cntr.RefTypePurch != 6 AND --Не закупка у единственного поставщика
  cntr.RefStage != -1 AND --Контракт завершен
  cntr.RefStage != 1 AND
  cntr.RefStage != 2 AND
  cntr.RefSignDate > 20150000 AND --Контракт заключен не ранее 2015 года
  guest.org_stats.org_cntr_num > 0 AND --Количество контрактов у организации больше 0
  guest.sup_stats.sup_cntr_num > 0 AND --Количество контрактов у поставщика больше 0
  guest.ter_stats.cntr_num > 0 --Количество контрактов по территории больше 0
  

--Заполнение хорошими контрактами
GO
INSERT INTO guest.sample
SELECT TOP(CAST(@@ROWCOUNT*1.5 AS INT))
val.ID, 
cntr.ID,
sup.ID,
org.ID,

--Поставщик
guest.sup_stats.sup_cntr_num,
guest.sup_stats.sup_running_cntr_num,
ROUND(1.0 * guest.sup_stats.sup_good_cntr_num / guest.sup_stats.sup_cntr_num, 3) AS 'sup_good_cntr_share',
ROUND(1.0 * guest.sup_stats.sup_fed_cntr_num / guest.sup_stats.sup_cntr_num, 3) AS 'sup_fed_cntr_share',
ROUND(1.0 * guest.sup_stats.sup_sub_cntr_num / guest.sup_stats.sup_cntr_num, 3) AS 'sup_sub_cntr_share',
ROUND(1.0 * guest.sup_stats.sup_mun_cntr_num / guest.sup_stats.sup_cntr_num, 3) AS 'sup_mun_cntr_share',
guest.sup_stats.sup_cntr_avg_price,
guest.sup_stats.sup_cntr_avg_penalty,
guest.sup_stats.sup_no_pnl_share,
guest.sup_stats.sup_1s_sev,
guest.sup_stats.sup_1s_org_sev,
guest.okpd_sup_stats.cntr_num AS 'sup_okpd_cntr_num',
guest.sup_similar_contracts_by_price_share(sup.ID, val.Price) AS 'sup_sim_price_share',
sup.RefStatusSup AS 'sup_status',
supType.Code AS 'sup_type',

--Заказчик
guest.org_stats.org_cntr_num,
guest.org_stats.org_running_cntr_num,
ROUND(1.0 * guest.org_stats.org_good_cntr_num / guest.org_stats.org_cntr_num, 3) AS 'org_good_cntr_share',
ROUND(1.0 * guest.org_stats.org_fed_cntr_num / guest.org_stats.org_cntr_num, 3) AS 'org_fed_cntr_share',
ROUND(1.0 * guest.org_stats.org_sub_cntr_num / guest.org_stats.org_cntr_num, 3) AS 'org_sub_cntr_share',
ROUND(1.0 * guest.org_stats.org_mun_cntr_num / guest.org_stats.org_cntr_num, 3) AS 'org_mun_cntr_share',
guest.org_stats.org_cntr_avg_price,
guest.org_stats.org_1s_sev,
guest.org_stats.org_1s_sup_sev,
guest.org_similar_contracts_by_price_share(org.ID, val.Price) AS 'org_sim_price_share',
guest.sup_org_stats.cntr_num AS 'cntr_num_together',
orgForm.code AS org_form,
org.RefTypeOrg AS org_type,

--ОКПД
guest.okpd_stats.good_cntr_num as 'okpd_good_cntr_num',
guest.okpd_stats.cntr_num AS 'okpd_cntr_num',
okpd.Code AS okpd, 

--Контракт
val.Price AS price,
val.PMP AS pmp,
val.RefLevelOrder AS cntr_lvl,
cntr.RefSignDate AS sign_date,
cntr.RefExecution AS exec_date,
cntr.RefTypePurch AS purch_type,
CASE WHEN (val.PMP > 0) AND (val.Price > val.PMP) THEN 1 ELSE 0 END AS price_higher_pmp,
CASE WHEN val.Price <= val.PMP * 0.6 THEN 1 ELSE 0 END AS price_too_low,

--Целевая переменная
guest.pred_variable(cntr.ID) AS cntr_result

FROM DV.f_OOS_Value AS val
INNER JOIN DV.d_OOS_Suppliers AS sup ON sup.ID = val.RefSupplier
INNER JOIN DV.d_OOS_Org AS org ON org.ID = val.RefOrg
INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
INNER JOIN DV.d_Territory_RF AS ter ON ter.ID = val.RefTerritory
INNER JOIN DV.f_OOS_Product AS prod ON prod.RefContract = cntr.ID
INNER JOIN DV.d_OOS_Products AS prods ON prods.ID = prod.RefProduct
INNER JOIN DV.d_OOS_OKPD2 AS okpd ON okpd.ID = prods.RefOKPD2
INNER JOIN DV.fx_OOS_PartType AS supType ON supType.ID = sup.RefPartType
INNER JOIN DV.fx_OOS_OrgForm AS orgForm ON orgForm.ID = sup.RefFormOrg
INNER JOIN guest.sup_stats ON sup.ID = guest.sup_stats.SupID
INNER JOIN guest.org_stats ON org.ID = guest.org_stats.OrgID
INNER JOIN guest.okpd_stats ON okpd.Code = guest.okpd_stats.code
INNER JOIN guest.ter_stats ON ter.Code1 = ter_stats.TerrID
INNER JOIN guest.okpd_sup_stats ON (okpd_sup_stats.SupID = sup.ID AND okpd_sup_stats.OkpdCode = okpd.Code)
INNER JOIN guest.sup_org_stats ON (sup_org_stats.SupID = sup.ID AND sup_org_stats.OrgID = org.ID)
WHERE 
  guest.pred_variable(cntr.ID) = 1 AND
  val.Price > 0 AND --Контракт реальный
  cntr.RefTypePurch != 6 AND --Не закупка у единственного поставщика
  cntr.RefStage != -1 AND --Контракт завершен
  cntr.RefStage != 1 AND
  cntr.RefStage != 2 AND
  cntr.RefSignDate > 20150000 AND --Контракт заключен не ранее 2015 года
  guest.org_stats.org_cntr_num > 0 AND --Количество контрактов у организации больше 0
  guest.sup_stats.sup_cntr_num > 0 AND --Количество контрактов у поставщика больше 0
  guest.ter_stats.cntr_num > 0 --Количество контрактов по территории больше 0
ORDER BY NEWID()