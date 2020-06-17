import sublime
import sublime_plugin
from os import makedirs, path

class ExtraFileCommandsNewCommand(sublime_plugin.WindowCommand):
    def is_visible(self, base):
        return base in self.window.extract_variables()

    def run(self, file, folder=None, base=None):
        if base is None and folder is None:
            raise TypeError("Either 'base' or 'folder' have to be passed")

        if folder is None:
            variables = self.window.extract_variables()
            folder = variables[base]

        file_path = path.normpath(path.join(folder, file))
        makedirs(path.dirname(file_path), exist_ok=True)
        try:
            open(file_path, "a").close()
        except OSError as e:
            sublime.error_message("%s:\n%s" % (e.strerror, e.filename))
        else:
            self.window.open_file(file_path)

    def input(self, args):
        base = args["base"]
        folders = self.window.folders()
        if base == "folder" and len(folders) > 1:
            return _FolderSelection(folders)
        else:
            variables = self.window.extract_variables()
            return _FileNameInput(variables[base])


class _FolderSelection(sublime_plugin.ListInputHandler):
    def __init__(self, folders):
        prefix, _, _ = path.commonprefix(folders).rpartition("/")
        prefix_length = len(prefix)

        self._folders = (
            folders if prefix_length == 0 else
            [("\u2026%s" % f[prefix_length:], f) for f in folders])

    def list_items(self):
        return self._folders[:]

    @staticmethod
    def name():
        return "folder"

    @staticmethod
    def placeholder():
        return "Select Base Folder"

    @staticmethod
    def description(value, text):
        return ""

    def next_input(self, args):
        return _FileNameInput(args["folder"])


class _FileNameInput(sublime_plugin.TextInputHandler):
    def __init__(self, folder):
        self._folder = folder

    @staticmethod
    def name():
        return "file"

    @staticmethod
    def placeholder():
        return "Enter File Name"

    def preview(self, file_name):
        return path.normpath(path.join(self._folder, file_name))

    def validate(self, file_name):
        return not path.exists(path.join(self._folder, file_name))
