[![Dhall logo](https://github.com/dhall-lang/dhall-lang/blob/master/img/dhall-logo.svg)](https://dhall-lang.org/)

[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://GitHub.com/s-zeng/dhall-python/graphs/commit-activity)
[![CI status](https://github.com/s-zeng/dhall-python/workflows/CI/badge.svg)](https://github.com/s-zeng/dhall-python/actions)
[![PyPI version shields.io](https://img.shields.io/pypi/v/dhall.svg)](https://pypi.python.org/pypi/dhall/)
[![PyPI downloads](https://img.shields.io/pypi/dm/dhall.svg)](https://pypistats.org/packages/dhall)

Dhall is a programmable configuration language optimized for
maintainability.

You can think of Dhall as: JSON + functions + types + imports

Note that while Dhall is programmable, Dhall is not Turing-complete.  Many
of Dhall's features take advantage of this restriction to provide stronger
safety guarantees and more powerful tooling.

You can try the language live in your browser by visiting the official website:

* [https://dhall-lang.org](http://dhall-lang.org/)

# `dhall-python`

`dhall-python` contains [Dhall][dhall-lang] bindings for Python using the 
[rust][dhall-rust] implementation. It is meant to be used to integrate Dhall 
into your python applications.

If you only want to convert Dhall to/from JSON or YAML, you should use the
official tooling instead; instructions can be found
[here](https://docs.dhall-lang.org/tutorials/Getting-started_Generate-JSON-or-YAML.html).

## Usage

Install using pip:

```shell
pip install dhall
```

Supports the following:

- Operating Systems
  - Windows
  - Mac OS
  - Linux (manylinux_2_24_x86_64)
- Python versions
  - 3.7
  - 3.8
  - 3.9
  - 3.10
  - 3.11

Python 3.5 and 3.6 support is available in older versions of dhall-python.

dhall-python implements a similar API to Python's [json
module](https://docs.python.org/3/library/json.html):

```python
>>> import dhall
>>> dhall.dumps({"keyA": 81, "keyB": True, "keyC": "value"})
'{ keyA = 81, keyB = True, keyC = "value" }'
>>> dhall.loads("""{ keyA = 81, keyB = True, keyC = "value" }""")
{'keyA': 81, 'keyB': True, 'keyC': 'value'}
```

# License

dhall-python is licensed under either of

- Apache License, Version 2.0, (LICENSE-APACHE or
  http://www.apache.org/licenses/LICENSE-2.0)
- MIT license (LICENSE-MIT or http://opensource.org/licenses/MIT)

at your option.

# Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in python-dhall by you, as defined in the Apache-2.0 license, shall
be dual licensed as above, without any additional terms or conditions.

All contributions are welcome! If you spot any bugs, or have any requests, 
issues and PRs are always welcome.

# Developer guide

This project uses [poetry](https://python-poetry.org/docs/) for managing the development environment. If you don't have it installed, run

```
curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python
export PATH="$HOME/.poetry/bin:$PATH"
```

The project requires the latest `stable` version of Rust.

Install it via `rustup`:

```
rustup install stable
```

If you have already installed the `stable` version, make sure it is up-to-date:

```
rustup update stable
```

After that, you can compile the current version of dhall-python and execute all tests and benchmarks with the following commands:

```
make install
make test
```

🤫 Pssst!... run `make help` to learn more.


[dhall-rust]: https://github.com/Nadrieril/dhall-rust
[dhall-lang]: https://dhall-lang.org
