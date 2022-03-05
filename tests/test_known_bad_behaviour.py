import string

import pytest
from hypothesis import given
from hypothesis import strategies as st

import dhall

# min, max: RFC 7159
st_negatives = st.integers(min_value=-(2**53) + 1, max_value=0)
st_naturals = st.integers(min_value=0, max_value=(2**53) - 1)
st_int = st.integers(min_value=-(2**53) + 1, max_value=(2**53) - 1)
st_floats = st.floats(min_value=-(2**53) + 1, max_value=(2**53) - 1)

keywords = ["as"]

st_failing_json = st.recursive(
    st.booleans() | st.text() | st_int,  # | st_floats
    lambda children: st.dictionaries(
        st.text(alphabet=string.digits, min_size=1) | st.sampled_from(keywords),
        children,
        min_size=1,
    ),
)

# KNOWN FAILURES: these tests demonstrate current undesired behaviour of python-dhall
# we should aim to make these tests fail :)


@given(st.none())
def test_none(xs):
    assert dhall.loads(dhall.dumps(xs)) != xs
    assert dhall.loads(dhall.dumps(xs)) == {}


# test lists of lists of integers w/ empty lists errors
# e.g. [[3, 4], [6], []]
@given(st.lists(st.lists(st_int), min_size=1).map(lambda lst: lst + [[]]))
def test_empty_list_in_list_of_lists(xs):
    with pytest.raises(TypeError):
        assert dhall.loads(dhall.dumps(xs)) == xs


@given(
    st.lists(st_naturals.filter(lambda x: x != 0), min_size=1).flatmap(
        lambda lstA: st.lists(st_negatives.filter(lambda x: x != 0), min_size=1).map(
            lambda lstB: lstA + lstB
        )
    )
)
def test_list_mixed_sign_integers(lst):
    with pytest.raises(TypeError):
        assert dhall.loads(dhall.dumps(lst)) == lst


# flaky test
# @given(st_failing_json.filter(lambda x: isinstance(x, dict)))
# def test_json_obj(j_obj):
#     with pytest.raises(TypeError):
#         assert dhall.loads(dhall.dumps(j_obj)) == j_obj
