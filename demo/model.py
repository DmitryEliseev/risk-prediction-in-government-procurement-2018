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
        self._numerical_params_file = 'numerical_params.json'
        self._categorical_params_file = 'categorical_params.json'

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
        data = get_data()

        # Балансировка
        data = CntrClassifier.balance_data(data)

        # Перемешивание
        data = data.sample(frac=1, random_state=RANDOM_SEED)

        # Предобработка
        X, y = self._prepocess_data(data)

        self._model = GradientBoostingClassifier(
            random_state=RANDOM_SEED,
            learning_rate=0.1,
            max_depth=3,
            n_estimators=100,
            subsample=0.85
        )

        self._model.fit(X, y)
        self._save_model()

    def predict(self, data):
        X, y = self._prepocess_data(data, train=False)
        return self._model.predict(X, y)

    def predict_proba(self, data):
        """Построение предсказаний"""

        X, y = self._prepocess_data(data, train=False)
        return self._model.predict_proba(X, y)

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

    def _prepocess_data(self, data, train=True):
        """Предобработка данных"""

        num_var, num_var01, cat_var, cat_bin_var = grouped_initial_vars()
        delete_useless_vars(num_var, num_var01, cat_var, cat_bin_var)

        data = self._process_numerical(data, num_var, num_var01, train=train)
        data = self._process_nominal(data, cat_var, cat_bin_var, train=train)

        data = data[num_var + num_var01 + cat_var + cat_bin_var + ['cntr_result']]

        X = data.drop(['cntr_result'], axis=1).values
        y = data.cntr_result.values

        return X, y

    @staticmethod
    def balance_data(data, good_prop=0.7):
        """
        Балансировка выборки так, чтобы хорошие составляли
        от общего числа контрактов долю, равную good_prop
        """
        bad_cntr = data.loc[data.cntr_result == 1]
        good_cntr = data.loc[data.cntr_result == 0]

        # Необходимое количество хороших контрактов
        needed_good_cntr = int(bad_cntr.shape[0] * good_prop / (1 - good_prop))

        good_cntr = good_cntr.sample(
            needed_good_cntr if needed_good_cntr < good_cntr.shape[0] else good_cntr.shape[0],
            random_state=RANDOM_SEED
        )

        logging.info('Соотношение хороших и плохих на обучающей выборке: ')

        return bad_cntr.append(good_cntr)

    def _process_numerical(self, data, num_var, num_var01, train=True):
        """Обработка количественных переменных"""
        if train:
            params = {'percentile': {}}
            self._scaler = StandardScaler()
        else:
            params = load_params(self._numerical_params_file)
            self._load_scaler()

        # Предобработка количественных переменных с нефиксированной областью значения
        for nv in data[num_var]:
            if train:
                dlimit = np.percentile(data[nv].values, 1)
                ulimit = np.percentile(data[nv].values, 99)
                params['percentile'][nv] = (dlimit, ulimit)
            else:
                dlimit = params['percentile'][nv][0]
                ulimit = params['percentile'][nv][1]

            data.loc[data[nv] > ulimit, nv] = ulimit
            data.loc[data[nv] < dlimit, nv] = dlimit

        save_params(self._numerical_params_file, params)

        # Логарифмирование
        for nv in data[num_var]:
            # Обработка значений меньших единицы
            data.loc[data[nv] < 1, nv] = 1
            data.loc[:, nv] = np.log(data[nv])

        # Шкалирование и центрирование
        if train:
            data.loc[:, num_var] = self._scaler.fit_transform(data[num_var])
            self._save_scaler()
        else:
            data.loc[:, num_var] = self._scaler.transform(data[num_var])

        return data

    def _process_nominal(self, data, cat_var, cat_bin_var, train=True):
        """Обработка номинальных переменных"""
        if train:
            params = {
                'grouping': {},  # Значения параметров, подлежащие группировке
                'woe': {}  # Значения параметров и соответствующая им WoE кодировка
            }

            # Группировка редких значений
            for cv in cat_var:
                params['grouping'][cv] = []
                cnt = data[cv].value_counts()
                for val, count in zip(cnt.index, cnt.values):
                    # Если значение встречается в менее 5% случаев
                    if count / data.shape[0] <= 0.005:
                        params['grouping'][cv].append(val)
                        data.loc[data[cv] == val, cv] = 'NEW'

            # WoE кодировка
            for cv in cat_var:
                cnt = data[cv].value_counts()
                params['woe'][cv] = {}
                for val, count in zip(cnt.index, cnt.values):
                    good_with_val = data.loc[(data.cntr_result == 1) & (data[cv] == val)].shape[0]
                    bad_with_val = data.loc[(data.cntr_result == 0) & (data[cv] == val)].shape[0]

                    p = good_with_val / data.loc[data.cntr_result == 1].shape[0]
                    q = bad_with_val / data.loc[data.cntr_result == 0].shape[0]
                    woe = round(np.log(p / q), 3)

                    params['woe'][cv][val] = woe
                    data.loc[data[cv] == val, cv] = woe

            save_params(self._categorical_params_file, params)
        else:
            params = load_params(self._categorical_params_file)
            for cv in cat_var:
                # Группировка
                data[cv] = data[cv].replace(params['grouping'][cv], 'NEW')

                # WoE кодирование
                data[cv] = data[cv].map(params['woe'][cv])

                # Кодировка для сгруппированной переменной NEW
                new_woe_code = params['woe'][cv].get('NEW', None)
                if new_woe_code:
                    # Замена неизвестных значений кодом для переменной NEW
                    data[cv] = data[cv].fillna(new_woe_code)
                else:
                    # Замена средним значением кода для этой переменной
                    avg_woe = np.average(data[data[cv].notnull()][cv])
                    data[cv] = data[cv].fillna(avg_woe)

        return data


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


def load_params(filename: str):
    """Считывание JSON из файла"""
    try:
        with open(filename, 'r', encoding='utf-8') as file:
            return json.loads(file.read())
    except FileNotFoundError as e:
        logging.error(e)


def save_params(filename: str, data: dict):
    """Запись JSON в файла"""
    with open(filename, 'w', encoding='utf-8') as file:
        return file.write(json.dumps(data))


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


if __name__ == '__main__':
    train_and_save_model()
