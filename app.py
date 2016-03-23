#
# Copyright 2016 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

from flask import Flask, abort, request, jsonify
from settings import APP_STATIC
import os
import re

app = Flask(__name__)

def get_config_data(mac_addr):
    pattern = '^%s' % mac_addr
    expr = re.compile(pattern)
    data = dict()
    with open(os.path.join(APP_STATIC, 'config.txt')) as f:
        for line in f:
            if expr.match(line):
                items = line.rstrip().split(',')
                data['mac_addr'] = items[0]
                data['role'] = items[1]

                return jsonify(data)
    return None


@app.route('/')
def index():
    return 'Clear Cloud Init Service... is alive\n'


@app.route('/get_config/<mac_addr>')
@app.route('/get_config/')
def get_config(mac_addr=None):
    reply = None
    if mac_addr is None:
        mac_addr = request.args.get('MAC')
    if mac_addr:
        reply = get_config_data(mac_addr)
        if not reply:
            return 'No config info for %s' % mac_addr
        else:
            return reply
    else:
        abort(404)


@app.route('/get_role/<role>')
@app.route('/get_role/')
def get_role(role=None):
    reply = None
    if role is None:
        role = request.args.get('role')
    if role:
        role_file = os.path.join(APP_STATIC, "roles", role)
        if os.path.isfile(role_file):
            with open(role_file) as f:
                return f.read()
        else:
            abort(404)
    else:
        abort(404)


@app.route('/foo')
def foo():
    with open(os.path.join(APP_STATIC, 'foo.txt')) as f:
        return f.read()

if __name__ == '__main__':
    app.run(debug=True)

