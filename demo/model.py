#!/usr/bin/python3
# -*- coding: utf-8 -*-

"""
Модель
"""

import pickle
import argparse
import json
import logging
# https://stackoverflow.com/questions/8562954/python-logging-to-different-destination-using-a-configuration-file

import numpy as np
import pandas as pd

from sklearn.ensemble import GradientBoostingClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import cross_validate

from demo.db import get_train_sample

from demo.config import config

RANDOM_SEED = 42


class CntrClassifier:
    def __init__(self, train=True):
        self._model = None
        self._scaler = None

        if train:
            self.train()
            self.save()
        else:
            self.load()

    def load(self):
        self._load_model()
        self._load_scaler()

    def save(self):
        self._save_model()
        self._save_scaler()

    def train(self):
        # TODO: Заглушка
        data = get_data()
        X, y = self._prepocess_data(data)

        self._model = GradientBoostingClassifier(
            random_state=RANDOM_SEED,
            eta=0.1,
            max_depth=3,
            n_estimators=100,
            subsample=0.85
        )

        self._model.fit(X, y)
        self._save_model()

    def predict(self):
        raise NotImplementedError

    def predict_proba(self, data: list):
        """Построение предсказаний"""

        """
        1. Предобработка данных
        2. Построение предсказания
        """

        raise NotImplementedError

    def _load_model(self):
        """Загрузка обученной модели"""
        try:
            with open('model.pkl', 'rb') as file:
                self._model = pickle.load(file)
        except FileNotFoundError as e:
            logging.error(e)

    def _load_scaler(self):
        """Загрузка нормализатора"""
        try:
            with open('scaler.pkl', 'rb') as file:
                self._scaler = pickle.load(file)
        except FileNotFoundError as e:
            logging.error(e)

    def _save_model(self):
        """Экспорт модели"""
        with open('model.pkl', 'wb') as file:
            pickle.dump(self._model, file)

    def _save_scaler(self):
        """Экспорт нормализатора"""
        with open('scaler.pkl', 'wb') as file:
            pickle.dump(self._scaler, file)

    def assess_model_quality(self, kfold=10):
        data = get_data()
        X, y = self._prepocess_data(data)

        metrics = ('roc_auc', 'accuracy', 'neg_log_loss')
        scores = cross_validate(self._model, X, y, scoring=metrics, cv=kfold, return_train_score=True)

        metric_keys = ['train_{}'.format(metric) for metric in metrics]
        metric_keys.extend(['test_{}'.format(metric) for metric in metrics])
        log_str = ', '.join('{}: M: {} STD: {}'.format(
            key, np.mean(scores[key]), np.std(scores[key])) for key in metric_keys)

        logging.info(log_str)

    def _prepocess_data(self, df, train=True):
        """Предобработка данных"""

        num_var, num_var01, cat_var, cat_bin_var = grouped_initial_vars()
        delete_useless_vars(num_var, num_var01, cat_var, cat_bin_var)

        df = self._process_numerical(df, num_var, num_var01, train=train)
        df = self._process_nominal(df, cat_var, cat_bin_var, train=train)

        used_vars = num_var + num_var01 + cat_var + cat_bin_var + ['cntr_result']
        X = df.drop(['cntr_result'], axis=1).values
        y = df.cntr_result.values

        return X, y

    def _process_numerical(self, df, num_var, num_var01, train=True):
        """Обработка количественных переменных"""
        return None

    def _process_nominal(self, df, cat_var, cat_bin_var, train=True):
        """Обработка номинальных переменных"""
        return None


def grouped_initial_vars():
    """Список сгруппированных по типу переменных"""

    # Список количественных переменных с нефиксированной областью значений
    num_var = [
        'sup_cntr_num', 'sup_running_cntr_num', 'sup_cntr_avg_price', 'org_cntr_num',
        'org_cntr_avg_price', 'org_running_cntr_num', 'price', 'pmp',
        'cntr_num_together', 'cntr_length', 'one_day_price'
    ]

    # Список количественных переменных с областью значений от 0 до 1 без учета 'sup_okpd_exp'
    num_var01 = [
        'sup_good_cntr_share', 'sup_fed_cntr_share', 'sup_sub_cntr_share',
        'sup_mun_cntr_share', 'sup_cntr_avg_penalty_share', 'sup_1s_sev', 'sup_1s_org_sev',
        'sup_no_pnl_share', 'sup_sim_price_share', 'org_good_cntr_share', 'org_fed_cntr_share',
        'org_sub_cntr_share', 'org_mun_cntr_share', 'org_1s_sev', 'org_1s_sup_sev', 'org_sim_price_share',
        'okpd_good_cntr_share'
    ]

    # Список категориальных переменных
    cat_var = ['org_type', 'okpd2', 'purch_type', 'quarter']

    # Список бинарных переменных
    cat_bin_var = ['price_higher_pmp', 'price_too_low']

    return num_var, num_var01, cat_var, cat_bin_var


def delete_useless_vars(num_var, num_var01, cat_var, cat_bin_var):
    """
    Удаление бесмысленных переменных на основе
    предварительного анализа данных
    """

    for nv in ('cntr_num_together', 'price', 'pmp'):
        num_var.remove(nv)

    for nv01 in (
            'sup_cntr_avg_penalty_share', 'sup_1s_sev', 'sup_1s_org_sev',
            'sup_no_pnl_share', 'org_fed_cntr_share', 'org_sub_cntr_share',
            'org_mun_cntr_share', 'org_1s_sev', 'org_1s_sup_sev'
    ):
        num_var01.remove(nv01)

    for cv in ():
        cat_var.remove(cv)

    cat_bin_var.clear()


def load_json_from_file(filename: str):
    """Считывание JSON из файла"""
    try:
        with open(filename, 'r', encoding='utf-8') as file:
            return json.loads(file.read())
    except FileNotFoundError as e:
        logging.error(e)


def save_json_to_file(filename: str, data: dict):
    """Запись JSON в файла"""
    with open(filename, 'w', encoding='utf-8') as file:
        return file.write(json.dump(data))


def get_data():
    data_source = config['data']['source']
    if data_source == 'csv':
        return pd.read_csv('../data/4/grbs_finished.csv', encoding='utf-8')
    else:
        return get_train_sample()


def train_and_save_model():
    CntrClassifier()


def predict(data):
    clf = CntrClassifier(train=False)
    return clf.predict_proba(data)
