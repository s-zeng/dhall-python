import os

import dhall


def test_samedir():
    os.chdir(os.path.dirname(os.path.realpath(__file__)) + "/relative_test")
    with open("b.dhall") as f:
        assert dhall.load(f) == "test_string!"
