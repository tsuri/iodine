#!/usr/bin/python

import libtmux
import os
import time

print ">>> %s " % os.path.abspath(__file__)


if not os.environ.get('TMUX'):
  print "Starting tmux"
  os.system('tmux new-session -n coreos -s tutorial')
  os.execv(os.path.abspath(__file__), [])

else:
  print "Connecting to tmux"
  server = libtmux.Server()
  session = server.find_where({ "session_name": "tutorial" })
  window = session.attached_window
  window.select_layout(layout="tiled")

  pane1 = window.split_window(attach=False)
  pane1.send_keys('vagrant ssh c01', enter=True)
  time.sleep(5)
  pane1.send_keys('watch -n 2 fleetctl list-machines', enter=True)


  pane2 = window.split_window(attach=False)
  pane2.send_keys('vagrant ssh c01', enter=True)
  time.sleep(5)
  pane2.send_keys('watch -n 2 etcdctl ls / --sort --recursive', enter=True)

  pane3 = window.split_window(attach=False)
  pane3.send_keys('vagrant ssh c01', enter=True)
  time.sleep(5)
  pane3.send_keys('watch -n 2 etcdctl member list', enter=True)
