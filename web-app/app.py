#!/usr/bin/python3
# -*- coding: utf-8 -*-

"""
Веб-приложение
"""

import json

from flask import Flask
from flask_restful import Api, Resource, reqparse, abort

from model import Model
from config import config

app = Flask(__name__)
api = Api(app)


class Prediction(Resource):
    def get(self):
        args = parser.parse_args()

        if not is_valid_api_key(args['apikey']):
            abort(403, message='API key %s is not valid' % args['apikey'])

        reg_nums = args['regnum']

        # Если данные передаются regnums=[1,2,3]
        if isinstance(reg_nums[0], list):
            reg_nums = reg_nums[0]

        model = Model(reg_nums)
        return model.predict()


def is_valid_api_key(api_key: str):
    """Валидация API ключа"""
    return api_key in config['api']['key']


parser = reqparse.RequestParser()
parser.add_argument('apikey', type=str, required=True, help='You need API key')
parser.add_argument('regnum', type=json.loads, action='append')

api.add_resource(Prediction, '/predict')


@app.route('/')
def main():
    return '<center><h1>Домашняя страница WEB API к МО-модели</h1></center>'


if __name__ == '__main__':
    app.run(debug=True)
