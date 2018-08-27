#!/usr/bin/python3
# -*- coding: utf-8 -*-

"""
Считывание файла настроек
"""

import configparser

config = configparser.ConfigParser()
config.read('sys_config.ini', encoding='utf-8')
