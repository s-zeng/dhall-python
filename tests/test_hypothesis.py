import string

import pytest
from hypothesis import given
from hypothesis import strategies as st

import dhall

# min, max: RFC 7159
st_naturals = st.integers(min_value=0, max_value=(2**53) - 1)
st_int = st.integers(min_value=-(2**53) + 1, max_value=(2**53) - 1)
st_floats = st.floats(min_value=-(2**53) + 1, max_value=(2**53) - 1)

st_text = st.text(alphabet=st.characters(blacklist_categories=["Cn", "Cs"]))

# st.floats would be nice, but then we need pytest.approx, which doesn't work with eg. text
st_json = st.recursive(
    st.booleans() | st_text | st.none() | st_int,  # | st_floats
    lambda children: st.lists(children) | st.dictionaries(st_text, children),
)

keywords = ["as"]

st_passing_json = st.recursive(
    st.booleans() | st_text | st_int,  # | st_floats
    lambda children: st.dictionaries(
        st.text(alphabet=string.ascii_letters).filter(lambda x: x not in keywords),
        children,
    ),
)


@given(st_floats)
def test_floats(xs):
    assert dhall.loads(dhall.dumps(xs)) == pytest.approx(xs)  # fails when abs=0.05


@given(st_text)
def test_text(xs):
    assert dhall.loads(dhall.dumps(xs)) == xs


@given(st.booleans())
def test_bool(xs):
    assert dhall.loads(dhall.dumps(xs)) == xs


@given(st.lists(st_naturals, min_size=1))
def test_list_naturals(lst):
    assert dhall.loads(dhall.dumps(lst)) == lst


@given(
    st.lists(st.floats(min_value=-(2**53) + 1, max_value=(2**53) - 1), min_size=1)
)
def test_list_floats(lst):
    assert dhall.loads(dhall.dumps(lst)) == pytest.approx(lst)


@given(st.lists(st_text, min_size=1))
def test_list_text(lst):
    assert dhall.loads(dhall.dumps(lst)) == lst


# TODO: fix https://pipelines.actions.githubusercontent.com/bvEb9nCIBV2sqdaDi8oIyVnWMTk9yQhCrOseL3I17XXo50cO3u/_apis/pipelines/1/runs/6/signedlogcontent/12?urlExpires=2020-10-31T16%3A16%3A29.9424385Z&urlSigningMethod=HMACV1&urlSignature=HNlGC9qiZr5whn66mFkdJlMoavo7ycV6%2BH9icX7mmRA%3D
# @given(st_passing_json)
# def test_json_obj(j_obj):
#     assert dhall.loads(dhall.dumps(j_obj)) == j_obj
