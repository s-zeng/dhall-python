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
        os.chdir(os.path.dirname(fp.name))
        return _dhall.load(fp)
