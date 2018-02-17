SELECT TOP(100)
cntr.ID,
DV.org_number_of_contracts(org.ID) AS 'org_cntr_num',
DV.org_one_side_severance_share(org.ID) AS 'org_1s_sev',
DV.org_supplier_one_side_severance_share(org.ID) AS 'org_1s_sup_sev',

DV.sup_avg_contract_price(sup.ID) AS 'sup_cntr_avg_price',
DV.sup_number_of_contracts(sup.ID) AS 'sup_cntr_num',
DV.sup_one_side_severance_share(sup.ID) AS 'sup_1s_sev',
DV.sup_organisation_one_side_severance_share(sup.ID) AS 'sup_1s_org_sev',

DV.pred_variable(cntr.ID) AS 'cntr_result'

FROM f_OOS_Value AS val
INNER JOIN DV.d_OOS_Suppliers AS sup ON sup.ID = val.RefSupplier
INNER JOIN DV.d_OOS_Org AS org ON org.ID = val.RefOrg
INNER JOIN DV.d_OOS_Contracts AS cntr ON cntr.ID = val.RefContract
INNER JOIN DV.fx_OOS_ContractStage AS cntrStg ON cntrStg.ID = cntr.RefStage
INNER JOIN DV.d_OOS_ClosContracts As cntrCls ON cntrCls.RefContract = cntr.ID
INNER JOIN DV.d_OOS_TerminReason AS cntrTrmnReas ON cntrTrmnReas.ID = cntrCls.RefTerminReason
INNER JOIN DV.d_OOS_Penalties AS cntrPenalt ON cntrPenalt.RefContract = cntr.ID

/*
Лимит 100 строк, первое исполнение
17.02.18

Без DISTINCT: 33 секунды 
С DISTINCT: 120 секунд +, а также ошибка деления на 0
*/