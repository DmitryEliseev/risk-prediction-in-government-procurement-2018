#!/usr/bin/python3
# -*- coding: utf-8 -*-

"""
Работа с БД
"""

import logging
import logging.config

import pandas as pd

import cx_Oracle
from sqlalchemy import create_engine

from demo.config import config

conf = config['database']

logging.config.fileConfig('log_config.ini')
logger = logging.getLogger('myLogger')


class Oracle:
    """Класс для работы с Oracle БД"""

    def __init__(self):
        self.engine = None
        self.con_string = 'oracle+cx_oracle://{user}:{pwd}'
        self.connect()

    def connect(self):
        """Подключение к БД"""

        db_name = conf['dbname']
        service_name = conf['service_name']

        if db_name and service_name:
            logger.warning('Указан SID и имя сервиса. Подсоединение произодет по SID')
            self.connect_with_sid()
        elif service_name:
            self.connect_with_sid()
        else:
            self.connect_with_service_name()

    def connect_with_sid(self, username, password, host, port, sid):
        """Подключение к БД с помощью SID"""

        connection_str = (self.con_string + '@{sid}').format(
            user=username,
            pwd=password,
            sid=cx_Oracle.makedsn(host, port, sid)
        )

        self.engine = create_engine(connection_str, echo=True)

    def connect_with_service_name(self, username, password, host, port, service_name):
        """Подключение к БД с помощью названия службы"""

        connection_str = (self.con_string + '@{service_name}').format(
            user=username,
            pwd=password,
            service_name=cx_Oracle.makedsn(host, port, service_name=service_name)
        )

        self.engine = create_engine(connection_str, echo=True)


def get_train_sample():
    """Сбор тренировочной выборки"""

    try:
        oracle = Oracle()
        return pd.read_sql_query('SELECT * FROM train_sample', oracle.engine, index_col='ID')
    except Exception as e:
        logger.error(e)


def get_sample_for_prediction():
    """Сбор выборки для построения предсказаний"""

    try:
        oracle = Oracle()
        return pd.read_sql_query('SELECT * FROM not_finished_cntr', oracle.engine, index_col='ID')
    except Exception as e:
        logger.error(e)


def update_predictions():
    """Обновление предсказания для выборки незавершенных контрактов"""

    raise NotImplementedError
