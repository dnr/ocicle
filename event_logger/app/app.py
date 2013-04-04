#!/usr/bin/env python

FILE_TEMPLATE = 'log-%Y%m%d'

import web
import json
import time

urls = (
  '/', 'index',
  '/log_event', 'log_event',
)

class index:
  def GET(self):
    return ''

class log_event:
  def POST(self):
    try:
      data = web.data()
      data = json.loads(data)
      assert type(data) == dict

      data['ua'] = web.ctx.env.get('HTTP_USER_AGENT')
      data['ip'] = web.ctx.env.get('REMOTE_ADDR')
      data['tm'] = time.time()

      data = json.dumps(data)

      fn = time.strftime(FILE_TEMPLATE)
      with open(fn, 'a') as f:
        f.write(data + '\0')

      return ''

    except:
      raise web.BadRequest()

application = web.application(urls, globals()).wsgifunc()
