
# The code in this files is borrowed from Gedit Synctex plugin.
#
# Copyright (C) 2010 Jose Aliste
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public Licence as published by the Free Software
# Foundation; either version 2 of the Licence, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public Licence for more
# details.
#
# You should have received a copy of the GNU General Public Licence along with
# this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
# Street, Fifth Floor, Boston, MA  02110-1301, USA

# Modified to Nvim-R by Jakson Aquino

import dbus
import dbus.mainloop.glib, sys, os
from gi.repository import GObject

RUNNING, CLOSED = range(2)

EV_DAEMON_PATH = "/org/gnome/evince/Daemon"
EV_DAEMON_NAME = "org.gnome.evince.Daemon"
EV_DAEMON_IFACE = "org.gnome.evince.Daemon"

EVINCE_PATH = "/org/gnome/evince/Evince"
EVINCE_IFACE = "org.gnome.evince.Application"

EV_WINDOW_IFACE = "org.gnome.evince.Window"


class EvinceWindowProxy:
    """A DBUS proxy for an Evince Window."""
    daemon = None
    bus = None

    def __init__(self, uri, spawn = False):
        self.uri = uri
        self.spawn = spawn
        self.status = CLOSED
        self.source_handler = None
        self.dbus_name = ''
        self._handler = None
        try:
            if EvinceWindowProxy.bus is None:
                EvinceWindowProxy.bus = dbus.SessionBus()

            if EvinceWindowProxy.daemon is None:
                EvinceWindowProxy.daemon = EvinceWindowProxy.bus.get_object(EV_DAEMON_NAME,
                                                EV_DAEMON_PATH,
                                                follow_name_owner_changes=True)
            EvinceWindowProxy.bus.add_signal_receiver(self._on_doc_loaded, signal_name="DocumentLoaded",
                                                      dbus_interface = EV_WINDOW_IFACE,
                                                      sender_keyword='sender')
            self._get_dbus_name(False)

        except dbus.DBusException:
            sys.stderr.write("Could not connect to the Evince Daemon")
            sys.stderr.flush()

    def _on_doc_loaded(self, uri, **keyargs):
        if uri == self.uri and self._handler is None:
            self.handle_find_document_reply(keyargs['sender'])

    def _get_dbus_name(self, spawn):
        EvinceWindowProxy.daemon.FindDocument(self.uri,spawn,
                     reply_handler=self.handle_find_document_reply,
                     error_handler=self.handle_find_document_error,
                     dbus_interface = EV_DAEMON_IFACE)

    def handle_find_document_error(self, error):
        sys.stderr.write("FindDocument DBus call has failed")
        sys.stderr.flush()

    def handle_find_document_reply(self, evince_name):
        if self._handler is not None:
            handler = self._handler
        else:
            handler = self.handle_get_window_list_reply
        if evince_name != '':
            self.dbus_name = evince_name
            self.status = RUNNING
            self.evince = EvinceWindowProxy.bus.get_object(self.dbus_name, EVINCE_PATH)
            self.evince.GetWindowList(dbus_interface = EVINCE_IFACE,
                          reply_handler = handler,
                          error_handler = self.handle_get_window_list_error)

    def handle_get_window_list_error (self, e):
        sys.stderr.write("GetWindowList DBus call has failed")
        sys.stderr.flush()

    def handle_get_window_list_reply (self, window_list):
        if len(window_list) > 0:
            window_obj = EvinceWindowProxy.bus.get_object(self.dbus_name, window_list[0])
            self.window = dbus.Interface(window_obj,EV_WINDOW_IFACE)
        else:
            #That should never happen.
            sys.stderr.write("GetWindowList returned empty list")
            sys.stderr.flush()


    def SyncView(self, input_file, data):
        if self.status == CLOSED:
            if self.spawn:
                self._tmp_syncview = [input_file, data, 0];
                self._handler = self._syncview_handler
                self._get_dbus_name(True)
                sys.stdout.write("call Evince_Again()")
                sys.stdout.flush()
        else:
            self.window.SyncView(input_file, data, 0,  dbus_interface = "org.gnome.evince.Window")
            sys.stdout.write("let g:rplugin_evince_loop = 0")
            sys.stdout.flush()

    def _syncview_handler(self, window_list):
        self.handle_get_window_list_reply(window_list)

        if self.status == CLOSED:
            return False
        self.window.SyncView(self._tmp_syncview[0],self._tmp_syncview[1], self._tmp_syncview[2], dbus_interface="org.gnome.evince.Window")
        del self._tmp_syncview
        self._handler = None
        return True

path_input = sys.argv[1]
path_output = sys.argv[2]
line_number = int(sys.argv[3])

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

a = EvinceWindowProxy('file://' + path_output, True)

def sync_view(ev_window, path_input, line_number):
    ev_window.SyncView(path_input, (line_number, 1))
    loop.quit()

GObject.timeout_add(400, sync_view, a, path_input, line_number)
loop = GObject.MainLoop()
loop.run()
