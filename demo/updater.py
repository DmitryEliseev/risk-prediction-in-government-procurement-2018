#!/usr/bin/python3
# -*- coding: utf-8 -*-

"""
Автоматическое регулярное обновления предсказаний
"""

import time
import schedule

from demo.db import update_predictions
from demo.db import get_sample_for_prediction
from demo.model import CntrClassifier
from demo.config import config


def update_predictions():
    """
    1. Получение новых данных
    2. Предобработка
    3. Построение предсказаний
    4. Занесение обратно
    """

    try:
        data = get_sample_for_prediction()
        model = CntrClassifier()
        predictions = model.predict_proba(data)
        update_predictions(predictions)
    # TODO: Определить Exception
    except Exception as e:
        # TODO: Логгирование
        print(e)


schedule.every().day.at(config['model']['update_time']).do(update_predictions)

while True:
    schedule.run_pending()
    time.sleep(1)
