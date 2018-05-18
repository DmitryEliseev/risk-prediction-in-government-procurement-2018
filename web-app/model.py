#!/usr/bin/python3
# -*- coding: utf-8 -*-

"""
Модель
"""

import random

class Model:
    def __init__(self, reg_nums: list):
        self.model_ = Model.load_model_()
        self.scaler_ = Model.load_scaler_()
        self.reg_nums = reg_nums

    @staticmethod
    def load_model_():
        """Загрузка обученной модели"""
        pass

    @staticmethod
    def load_scaler_():
        """Загрузка нормализатора"""
        pass

    @staticmethod
    def prepocess_data_(data: list):
        """Предобработка данных"""
        pass

    def predict(self):
        """Построение предсказаний"""

        """
        1. Сбор данных по reg_nums
        2. Предобработка данных
        3. Построение предсказания
        """

        # TODO: убрать заглушка по построению предсказания
        response = []
        for reg_num in self.reg_nums:
            # Случайные предсказания
            pred_class = random.randint(0, 1)
            pred_proba = random.uniform(0, 0.49) if not pred_class else random.uniform(0.5, 1)
            response.append({'reg_num': reg_num, 'pred_class': pred_class, 'pred_proba': round(pred_proba, 2)})

        return response
