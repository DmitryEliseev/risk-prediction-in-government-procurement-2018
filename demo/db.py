#!/usr/bin/python3
# -*- coding: utf-8 -*-

"""
Работа с БД
"""

import logging
import logging.config

import pandas as pd

import cx_Oracle
from sqlalchemy import create_engine, exc

from config import config

logging.config.fileConfig('log_config.ini')
logger = logging.getLogger('myLogger')

db_conf = config['database']


class Oracle:
    """Класс для работы с Oracle БД"""

    def __init__(self):
        self.engine = None
        self.con_string = 'oracle+cx_oracle://{user}:{pwd}'
        self.connect()

    def connect(self):
        """Подключение к БД"""

        username = db_conf['username']
        pwd = db_conf['pwd']
        host = db_conf['host']
        port = db_conf['port']
        db_name = db_conf['db_name']
        service_name = db_conf['service_name']

        if db_name and service_name:
            logger.warning(
                'В файле конфигурации указан SID и имя сервиса. '
                'Подсоединение произодет по SID'
            )

        if db_name:
            self.connect_with_sid(username, pwd, host, port, db_name)
        else:
            self.connect_with_service_name(username, pwd, host, port, service_name)

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

    oracle = Oracle()
    try:
        data = pd.read_sql_query('SELECT * FROM train_sample', oracle.engine, index_col='ID')
        return data
    except exc.DatabaseError as e:
        logger.error('Ошибка подключения к БД: {}'.format(e))
        exit(1)


def get_sample_for_prediction():
    """Сбор выборки для построения предсказаний"""

    oracle = Oracle()
    try:
        data = pd.read_sql_query('SELECT * FROM not_finished_cntr', oracle.engine, index_col='ID')
        return data
    except exc.DatabaseError as e:
        logger.error('Ошибка подключения к БД: {}'.format(e))
        exit(1)


def update_predictions():
    """Обновление предсказания для выборки незавершенных контрактов"""

    raise NotImplementedError
