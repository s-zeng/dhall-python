#!/usr/bin/env bash

cargo fmt
isort .
black .
