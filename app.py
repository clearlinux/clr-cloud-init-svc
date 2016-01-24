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

from flask import Flask, abort, request
from settings import APP_STATIC
import os

app = Flask(__name__)

def get_config_data(mac_addr):
    return 'controller1,192.168.6.1,the rest...\n'

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

@app.route('/foo')
def foo():
    with open(os.path.join(APP_STATIC, 'foo.txt')) as f:
        return f.read()

if __name__ == '__main__':
    app.run(debug=True)

