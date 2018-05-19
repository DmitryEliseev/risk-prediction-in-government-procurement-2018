#!/usr/bin/python3
# -*- coding: utf-8 -*-

"""
Работа с БД
"""

import pandas as pd
import pyodbc
from config import config

conf = config['database']
cnxn = pyodbc.connect(
    (
        "Driver=SQL Server Native Client 11.0;"
        "Server={};"
        "Database={};"
        "uid={};pwd={}").format(
        conf['server_name'],
        conf['database_name'],
        conf['user_name'],
        conf['password']
    )
)


def get_data(reg_nums: list):
    """
    Получение данных из БД
    """

    # Некоторые регистрационные номера контрактов для тестирования
    # TODO: убрать заглушку
    reg_nums_to_query = reg_nums = (
        '1760600872315000024',
        '1760403442115000041',
        '1760401604515000014',
        '1760602146716000122',
        '1760600236915000069',
        '1760702296015000017',
        '1762200442016000019'
    )

    # Выявление контрактов, по которым данных в кэше нет
    if get_data.data:
        not_cached_reg_nums = set(get_data.data.cntr_reg_num.values).difference(reg_nums)
        reg_nums_to_query = not_cached_reg_nums

    # Преобразования массива в строку вида reg_num1.reg_num2.reg_num3...
    reg_nums_str = '.'.join(reg_nums_to_query)

    # Запрос к БД
    data = pd.read_sql_query("EXEC guest.sp_get_data '{}'".format(reg_nums_str), cnxn)

    # Обновление кэша
    if get_data.data:
        get_data.data = pd.concat([get_data.data, data])
    else:
        get_data.data = data

    return get_data.data.loc[get_data.data.cntr_reg_num.isin(reg_nums)]


get_data.data = None
