import contextlib
import os

from . import dhall as _dhall
from .dhall import __version__, dump, dumps, loads


@contextlib.contextmanager
def remember_cwd():
    curdir = os.getcwd()
    try:
        yield
    finally:
        os.chdir(curdir)


def load(fp):
    with remember_cwd():
        newdir = os.path.dirname(fp.name)
        if newdir != "":
            os.chdir(newdir)
        return _dhall.load(fp)
