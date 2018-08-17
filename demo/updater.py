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
    Регулярное обновление предсказаний
    """

    try:
        model = CntrClassifier(train=False)

        data = get_sample_for_prediction()
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
