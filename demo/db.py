#!/usr/bin/python3
# -*- coding: utf-8 -*-

"""
Работа с БД
"""

# TODO: вместо cx_Oracle использовать sqlalchemy

import logging
import logging.config

import cx_Oracle
from demo.config import config

conf = config['database']

logging.config.fileConfig('log_config.ini')
logger = logging.getLogger('myLogger')


class Oracle:
    def __init__(self):
        self.db = None
        self.cursor = None

    def connect(self, username, password, hostname, port, service_name):
        try:
            self.db = cx_Oracle.connect(
                username,
                password,
                '{}:{}/{}'.format(hostname, port, service_name)
            )
            self.cursor = self.db.cursor()

            # Количество строк, считываемых за раз: https://cx-oracle.readthedocs.io/en/latest/cursor.html
            self.cursor.arraysize = 10000
        except cx_Oracle.DatabaseError as e:
            logger.error('Database connection error: {}'.format(e))
            raise

    def disconnect(self):
        try:
            self.cursor.close()
            self.db.close()
        except cx_Oracle.DatabaseError:
            pass

    def execute(self, sql, bindvars=None, commit=False):
        try:
            self.cursor.execute(sql, bindvars)
        except cx_Oracle.DatabaseError as e:
            logger.error('Database connection error: {}'.format(e))
            raise

        if commit:
            self.db.commit()

        return self.cursor


def get_train_sample():
    """Сбор тренировочной выборки"""

    oracle = Oracle()
    oracle.connect(conf['username'], conf['pwd'], conf['host'], conf['port'], conf['service_name'])

    # Выбор всех данных для тренировочной выборки
    sql_statement = 'SELECT * FROM train_sample'

    # ora_conn = cx_Oracle.connect('your_connection_string')
    # df_ora = pd.read_sql('select * from user_objects', con=ora_conn)

    try:
        cursor = oracle.execute(sql_statement)
        return cursor.fetchall()
    finally:
        oracle.disconnect()


def get_sample_for_prediction():
    """Сбор выборки для построения предсказаний"""

    oracle = Oracle.connect(
        conf['username'], conf['pwd'], conf['host'], conf['port'], conf['service_name']
    )

    # Выбор всех данных для тренировочной выборки
    sql_statement = 'SELECT * FROM not_finished_cntr'

    try:
        cursor = oracle.execute(sql_statement)
        return cursor.fetchall()
    finally:
        oracle.disconnect()


def update_predictions():
    """Обновление предсказания для выборки незавершенных контрактов"""

    raise NotImplementedError
