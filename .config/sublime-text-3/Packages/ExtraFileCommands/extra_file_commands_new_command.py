import sublime_plugin


class ExtraFileCommandsDeleteCommand(sublime_plugin.WindowCommand):
    def is_visible(self):
        return bool(_FileName.for_plugin(self))

    def run(self, close=False):
        file_name = _FileName.for_plugin(self)
        if file_name:
            _remove(str(file_name))
            if close:
                self._close_view()

    def _close_view(self):
        view = self.window.active_view()
        view.set_scratch(True)
        view.close()


class _FileName:
    @classmethod
    def for_window(cls, window):
        view = window.active_view()
        return _FileName(view.file_name() if view else None)

    @classmethod
    def for_plugin(cls, plugin):
        return cls.for_window(plugin.window)

    def __init__(self, file_name):
        self._file_name = file_name

    def name(self):
        return self._file_name

    def __bool__(self):
        return self._file_name is not None

    def __str__(self):
        return self.name()


def _remove(file_name):
    try:
        import Default.send2trash.send2trash as send2trash
        remove = send2trash.send2trash
    except ImportError:
        try:
            import Default.send2trash as send2trash
            remove = send2trash.send2trash
        except ImportError:
            import os
            remove = os.remove
    remove(file_name)
