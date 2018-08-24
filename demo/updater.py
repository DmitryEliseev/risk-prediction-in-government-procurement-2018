#!/usr/bin/python3
# -*- coding: utf-8 -*-

"""
Автоматическое регулярное обновления предсказаний
"""

import time
import schedule
import threading

import logging
import logging.config

from db import update_predictions as update
from db import get_sample_for_prediction
from model import CntrClassifier
from model import train_and_save_model
from config import config

logging.config.fileConfig('log_config.ini')
logger = logging.getLogger('myLogger')


def run_threaded(job_func):
    """Функция для обработки случая однорвеменного апдейта модели и предсказаний"""

    job_thread = threading.Thread(target=job_func)
    job_thread.start()


def update_predictions():
    """Регулярное обновление предсказаний"""

    try:
        model = CntrClassifier(train=False)

        data = get_sample_for_prediction()
        predictions = model.predict_proba(data)
        update(predictions)
    # TODO: Определить Exception
    except Exception as e:
        logger.error(e)


def retrain_model():
    """Регулярное обновление модели"""

    try:
        train_and_save_model()
    # TODO: Определить Exception
    except Exception as e:
        logger.error(e)


UPDATE_TIME = config['model']['update_time']
RETRAIN_PERIOD = int(config['model']['retrain_period'])

# Установка периодичности и времени переобучения (обновления) модели
schedule.every(RETRAIN_PERIOD).days.at(UPDATE_TIME).do(run_threaded, retrain_model)

# Установка времени обновления предсказаний
schedule.every().day.at(UPDATE_TIME).do(run_threaded, update_predictions)

while True:
    schedule.run_pending()
    time.sleep(1)
