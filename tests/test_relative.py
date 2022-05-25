import os

import dhall


def test_relative():
    with open(
        os.path.dirname(os.path.realpath(__file__)) + "/relative_test/b.dhall"
    ) as f:
        assert dhall.load(f) == "test_string!"
