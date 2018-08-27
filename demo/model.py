#!/usr/bin/python3
# -*- coding: utf-8 -*-

"""
Модель
"""

import logging
import logging.config

# import demo.logs_helper
import pickle
import json
import os
import argparse
import warnings

warnings.filterwarnings('ignore')

import numpy as np
import pandas as pd

from sklearn.ensemble import GradientBoostingClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.model_selection import StratifiedKFold
from sklearn.metrics import accuracy_score, roc_auc_score, log_loss

from time import time

from db import get_train_sample
from config import config

RANDOM_SEED = 42

logging.config.fileConfig('log_config.ini')
logger = logging.getLogger('myLogger')

model_conf = config['model']


class CntrClassifier:
    """Класс для работы с моделью, предсказывающей рискованность госконтрактов"""

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

        # Инициализация модели
        self._model = GradientBoostingClassifier(
            random_state=RANDOM_SEED,
            learning_rate=0.1,
            max_depth=3,
            n_estimators=100,
            subsample=0.85
        )

        # Обучение модели
        self._model.fit(X, y)

        # Сохранение модели и скейлера
        self._save_model()

    def predict(self, data):
        """Построение предсказаний"""
        X, y = self._prepocess_data(data, train=False)
        return self._model.predict(X, y)

    def predict_proba(self, data):
        """Построение вероятностных предсказаний"""

        X, y = self._prepocess_data(data, train=False)
        return self._model.predict_proba(X, y)

    def _load_model(self):
        """Загрузка обученной модели"""

        try:
            with open('model.pkl', 'rb') as file:
                self._model = pickle.load(file)
        except FileNotFoundError as e:
            logger.error(e)

    def _load_scaler(self, prefix=''):
        """Загрузка нормализатора"""

        try:
            with open(prefix + 'scaler.pkl', 'rb') as file:
                self._scaler = pickle.load(file)
        except FileNotFoundError as e:
            logger.error(e)

    def _save_model(self):
        """Экспорт модели"""

        with open('model.pkl', 'wb') as file:
            pickle.dump(self._model, file)

    def _save_scaler(self, prefix=''):
        """Экспорт нормализатора"""

        with open(prefix + 'scaler.pkl', 'wb') as file:
            pickle.dump(self._scaler, file)

    def cross_validate(self, model, data, scoring, cv=10, return_train_score=False):
        """Кросс-валидация с учетом переподсчета WoE, перцентилей и др."""

        PREFIX = 'cv_'
        scores = {}
        types = ('train_', 'test_')
        scores['fit_time'] = []

        for type in types:
            if type == 'train_':
                if not return_train_score:
                    continue
            for metric in scoring:
                scores[type + metric] = []

        X, y = data.values, data.cntr_result.values
        skf = StratifiedKFold(n_splits=cv, random_state=RANDOM_SEED)
        skf.get_n_splits(X, y)

        for train_index, test_index in skf.split(X, y):
            data_train, data_test = data.loc[train_index], data.loc[test_index]

            X_train, y_train = self._prepocess_data(data_train, train=True, prefix=PREFIX)
            X_test, y_test = self._prepocess_data(data_test, train=False, prefix=PREFIX)

            # Удаление ненужных файлов
            try:
                for file in (
                            PREFIX + self._categorical_params_file,
                            PREFIX + self._numerical_params_file,
                            PREFIX + 'scaler.pkl'
                ):
                    os.remove(file)
            except FileNotFoundError as e:
                logger.error(e)

            start_time = time()
            model.fit(X_train, y_train)
            end_time = time()
            scores['fit_time'].append(end_time - start_time)

            for type in types:
                if type == 'train_':
                    y_true = y_train
                    X = X_train

                    if not return_train_score:
                        continue

                else:
                    y_true = y_test
                    X = X_test

                for metric in scoring:
                    score = 0
                    if metric == 'accuracy':
                        y_hat = model.predict(X)
                    else:
                        y_hat = model.predict_proba(X)[:, 1]

                    if metric == 'roc_auc':
                        score = roc_auc_score(y_true, y_hat)
                    elif metric == 'neg_log_loss':
                        score = -log_loss(y_true, y_hat)
                    else:
                        score = accuracy_score(y_true, y_hat)

                    scores[type + metric].append(score)
        return scores

    def assess_model_quality_cv(self, kfold=10, return_train_score=True):
        """Оценка качества модели на кросс-валидации"""

        logger.info('Тестирование на кросс-валидации: K = %s' % kfold)
        data = get_data()

        metrics = ('roc_auc', 'accuracy', 'neg_log_loss')
        scores = self.cross_validate(self._model, data, scoring=metrics, cv=kfold,
                                     return_train_score=return_train_score)

        metric_keys = []

        if return_train_score:
            metric_keys.extend(['train_{}'.format(metric) for metric in metrics])

        metric_keys.extend(['test_{}'.format(metric) for metric in metrics])
        log_str = ', '.join('{}: M: {:.3f} STD: {:.3f}'.format(
            key, np.mean(scores[key]), np.std(scores[key])) for key in metric_keys)

        log_str += ', {}: M: {:.3f} STD: {:.3f}'.format(
            'fit_time', np.mean(scores['fit_time']), np.std(scores['fit_time'])
        )

        logger.info(log_str)

    def assess_model_quality_train_test_split(self, test_size=0.25):
        """Оценка качества модели на отложенной выборке"""

        logger.info('Тестирование на отложенной выборке ({})'.format(test_size))

        data = get_data()

        train_data, test_data = train_test_split(data, random_state=RANDOM_SEED, test_size=test_size)

        PREFIX = 'split_'
        X_train, y_train = self._prepocess_data(train_data, train=True, prefix=PREFIX)
        X_test, y_test = self._prepocess_data(test_data, train=False, prefix=PREFIX)

        # Удаление ненужных файлов
        try:
            for file in (
                        PREFIX + self._categorical_params_file,
                        PREFIX + self._numerical_params_file,
                        PREFIX + 'scaler.pkl'
            ):
                os.remove(file)
        except FileNotFoundError as e:
            logger.error(e)

        baseline_model = self._model

        baseline_model.fit(X_train, y_train)

        # Вероятность принадлежности классу 1
        y_hat_proba = baseline_model.predict_proba(X_test)[:, 1]
        y_hat_class = baseline_model.predict(X_test)

        # Интересующие метрики качества
        accuracy = round(accuracy_score(y_test, y_hat_class), 3)
        roc_auc = round(roc_auc_score(y_test, y_hat_proba), 3)
        neg_log_loss = round(-log_loss(y_test, y_hat_proba), 3)

        logger.info(
            'test_accuracy = ' + str(accuracy) + ',' \
            + ' test_roc_auc = ' + str(roc_auc) + ',' \
            + ' test_neg_log_loss = ' + str(neg_log_loss)
        )

    def _prepocess_data(self, data, train=True, prefix=''):
        """Предобработка данных"""

        num_var, num_var01, cat_var, cat_bin_var = grouped_initial_vars()
        delete_useless_vars(num_var, num_var01, cat_var, cat_bin_var)

        data = self._process_numerical(data, num_var, num_var01, train=train, prefix=prefix)
        data = self._process_nominal(data, cat_var, cat_bin_var, train=train, prefix=prefix)

        data = data[num_var + num_var01 + cat_var + cat_bin_var + ['cntr_result']]

        X = data.drop(['cntr_result'], axis=1).values
        y = data.cntr_result.values

        return X, y

    @staticmethod
    def balance_data(data, good_prop=0.7):
        """
        Балансировка выборки так, чтобы хорошие составляли
        от общего числа контрактов долю = good_prop
        """
        bad_cntr = data.loc[data.cntr_result == 1]
        good_cntr = data.loc[data.cntr_result == 0]

        # Необходимое количество хороших контрактов
        needed_good_cntr = int(bad_cntr.shape[0] * good_prop / (1 - good_prop))

        good_cntr = good_cntr.sample(
            needed_good_cntr if needed_good_cntr < good_cntr.shape[0] else good_cntr.shape[0],
            random_state=RANDOM_SEED
        )

        data = bad_cntr.append(good_cntr)

        logger.debug(
            'Значение параметра "доля плохих контрактов" на обучающей выборке: {:.2f}'
                .format(1 - good_prop)
        )

        logger.debug(
            'Фактическая доля плохих контрактов: {:.2f}'
                .format(bad_cntr.shape[0] / data.shape[0])
        )

        return data

    def _process_numerical(self, data, num_var, num_var01, train=True, prefix='', ):
        """Обработка количественных переменных"""

        if train:
            params = {'percentile': {}}
            self._scaler = StandardScaler()
        else:
            params = load_params(prefix + self._numerical_params_file)
            self._load_scaler(prefix)

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

        save_params(prefix + self._numerical_params_file, params)

        # Логарифмирование
        for nv in data[num_var]:
            # Обработка значений меньших единицы
            data.loc[data[nv] < 1, nv] = 1
            data.loc[:, nv] = np.log(data[nv])

        # Шкалирование и центрирование
        if train:
            data.loc[:, num_var] = self._scaler.fit_transform(data[num_var])
            self._save_scaler(prefix)
        else:
            data.loc[:, num_var] = self._scaler.transform(data[num_var])

        return data

    def _process_nominal(self, data, cat_var, cat_bin_var, train=True, prefix=''):
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
                    # Если значение встречается в менее 0.5% случаев
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

            save_params(prefix + self._categorical_params_file, params)
        else:
            params = load_params(prefix + self._categorical_params_file)
            for cv in cat_var:
                # Группировка
                if params['grouping'][cv]:
                    data[cv] = data[cv].replace(params['grouping'][cv], 'NEW')

                # WoE кодирование
                data[cv] = data[cv].astype(str).map(params['woe'][cv])

                # Обработка случая, когда в тестовой выборке есть значения переменной,
                # которые не встречались в тренировочной
                if np.sum(data[cv].isnull()) > 0:
                    # Кодировка для сгруппированной переменной NEW
                    new_woe_code = params['woe'][cv].get('NEW', None)
                    if new_woe_code:
                        # Замена неизвестных значений кодом для переменной NEW
                        data[cv] = data[cv].fillna(new_woe_code)
                    else:
                        data[cv] = data[cv].fillna(0)

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
    Удаление бесмысленных переменных на основе предварительного анализа данных
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
        logger.error(e)


def save_params(filename: str, data: dict):
    """Запись JSON в файл"""

    with open(filename, 'w', encoding='utf-8') as file:
        return file.write(json.dumps(data))


def get_data():
    """Считывание исходных данных"""

    data_source = model_conf['source']
    if data_source == 'csv':
        return pd.read_csv('../data/4/grbs_finished.csv', encoding='utf-8')
    else:
        return get_train_sample()


def train_and_save_model():
    """Обучение модели и сохранение параметров"""

    CntrClassifier()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()

    parser.add_argument(
        '--test',
        help='Принимает единственный аргумент. '
             'Если 1 или double, то модель тестируется на отложенной выборке. '
             'Если целое число, то модель тестируется на SK-fold cross-validation.',
        nargs=1
    )

    parser.add_argument(
        '--train',
        help='Обучает модель на всей доступной выборке.',
        action='store_true'
    )

    args = parser.parse_args()

    if args.train:
        logger.info('Начато обучение модели')
        train_and_save_model()
        logger.info('Закончено обучение модели')

    if args.test:
        logger.info('Начато тестирование модели')

        test_arg = args.test[0]

        if test_arg.replace(".", "", 1).isdigit():
            if '.' in test_arg:
                # Тестирование на отложенной выборке с соотношением тестовой выборки равным test_arg
                CntrClassifier(train=False).assess_model_quality_train_test_split(test_size=float(test_arg))
            elif int(test_arg) == 1:
                # Тестирование на отложенной выборке с соотношением обучающей и тестовой по умолчанию
                CntrClassifier(train=False).assess_model_quality_train_test_split()
            else:
                # Тестирование на кросс-валидации с количеством фолдов равным test_arg
                CntrClassifier(train=False).assess_model_quality_cv(kfold=int(test_arg))
        else:
            msg_error = 'Неверное значение аргумента --test: {}. Должен быть INT или FLOAT'.format(test_arg)
            logger.error(msg_error)
            raise ValueError(msg_error)

        logger.info('Закончено тестирование модели')
