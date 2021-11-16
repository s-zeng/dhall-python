let GithubActions =
      https://raw.githubusercontent.com/regadas/github-actions-dhall/64c7852d0690ec7a50bfcb5911aa9ec614a09a36/package.dhall
        sha256:66b276bb67cca4cfcfd1027da45857cc8d53e75ea98433b15dade1e1e1ec22c8

let Prelude =
      https://prelude.dhall-lang.org/v21.0.0/package.dhall
        sha256:46c48bba5eee7807a872bbf6c3cb6ee6c2ec9498de3543c5dcc7dd950e43999d

let ghVar
    : Text -> Text
    = \(varName : Text) -> "\${{ ${varName} }}"

let setupPython
    : Text -> GithubActions.Step.Type
    = \(version : Text) ->
        GithubActions.Step::{
        , uses = Some "actions/setup-python@v2"
        , name = Some "Setup python ${version}"
        , `with` = Some (toMap { python-version = version })
        }

let setupRust
    : GithubActions.Step.Type
    = GithubActions.Step::{
      , uses = Some "actions-rs/toolchain@v1"
      , name = Some "Install Rust"
      , `with` = Some (toMap { toolchain = "stable", override = "true" })
      }

let DependencySet = < Full | Lint | Bump >

let installDeps
    : DependencySet -> GithubActions.Step.Type
    = \(installType : DependencySet) ->
        let fullDeps =
              [ "pip install poetry"
              , "touch Cargo.toml.orig"
              , "poetry install"
              ]

        let deps =
              merge
                { Full = fullDeps
                , Lint = [ "pip install black isort autoflake" ]
                , Bump = [ "cargo install cargo-bump" ] # fullDeps
                }
                installType

        in  GithubActions.Step::{
            , name = Some "Install dependencies"
            , run = Some
                ( Prelude.Text.concatSep
                    "\n"
                    ([ "python -m pip install --upgrade pip" ] # deps)
                )
            }

let latestPython = "3.10"

let supportPythons = [ "3.6", "3.7", "3.8", "3.9", "3.10" ]

let supportedOSs = [ "ubuntu-latest", "macos-latest", "windows-latest" ]

let releaseCreatedCondition =
      "github.event_name == 'release' && github.event.action == 'created'"

in  GithubActions.Workflow::{
    , name = "CI"
    , on = GithubActions.On::{
      , push = Some GithubActions.Push::{ branches = Some [ "master" ] }
      , pull_request = Some GithubActions.PullRequest::{
        , branches = Some [ "master" ]
        }
      , release = Some GithubActions.Release::{
        , types = Some [ GithubActions.types.Release/types.created ]
        }
      , schedule = Some [ { cron = "20 23 * * 6" } ]
      }
    , jobs = toMap
        { lint = GithubActions.Job::{
          , name = Some "Lint check"
          , runs-on = GithubActions.RunsOn.Type.ubuntu-latest
          , steps =
            [ GithubActions.steps.actions/checkout
            , setupPython latestPython
            , installDeps DependencySet.Lint
            , GithubActions.Step::{
              , name = Some "Check lint"
              , run = Some
                  ( Prelude.Text.concatSep
                      "\n"
                      [ "isort . --check --diff -rc", "black . -- check" ]
                  )
              }
            ]
          }
        , build = GithubActions.Job::{
          , name = Some "Build and test wheels"
          , runs-on = GithubActions.RunsOn.Type.`${{ matrix.os }}`
          , needs = Some [ "lint" ]
          , `if` = Some "github.event.name != 'release'"
          , strategy = Some GithubActions.Strategy::{
            , fail-fast = Some True
            , matrix = toMap
                { os = supportedOSs, python-version = supportPythons }
            }
          , steps =
            [ GithubActions.steps.actions/checkout
            , setupPython (ghVar "matrix.python-version")
            , setupRust
            , installDeps DependencySet.Full
            , GithubActions.Step::{
              , name = Some "Maturin build and pytest"
              , run = Some
                  ( Prelude.Text.concatSep
                      "\n"
                      [ "poetry run maturin build"
                      , "poetry run maturin develop"
                      , "poetry run pytest tests"
                      ]
                  )
              }
            ]
          }
        , publish = GithubActions.Job::{
          , name = Some "Publish wheels to PyPI"
          , runs-on = GithubActions.RunsOn.Type.`${{ matrix.os }}`
          , needs = Some [ "build" ]
          , `if` = Some releaseCreatedCondition
          , strategy = Some GithubActions.Strategy::{
            , fail-fast = Some True
            , matrix = toMap
                { os = supportedOSs, python-version = supportPythons }
            }
          , steps =
            [ GithubActions.steps.actions/checkout
            , setupPython (ghVar "matrix.python-version")
            , setupRust
            , installDeps DependencySet.Full
            , GithubActions.Step::{
              , name = Some "Build python package"
              , run = Some
                  "poetry run maturin build --release --strip --interpreter python${ghVar
                                                                                      "matrix.python-version"}"
              }
            , GithubActions.Step::{
              , name = Some "Install wheels"
              , `if` = Some "matrix.os == 'windows-latest'"
              , run = Some "pip install --find-links=target\\wheels dhall"
              }
            , GithubActions.Step::{
              , name = Some "Install wheels"
              , `if` = Some "matrix.os != 'windows-latest'"
              , run = Some "pip install target/wheels/dhall*.whl"
              }
            , GithubActions.Step::{
              , name = Some "Release"
              , uses = Some "softprops/action-gh-release@v1"
              , `if` = Some "startsWith(github.ref, 'refs/tags/'"
              , `with` = Some (toMap { files = "target/wheels/dhall*.whl" })
              , env = Some
                  (toMap { GITHUB_TOKEN = ghVar "secrets.GITHUB_TOKEN" })
              }
            , GithubActions.Step::{
              , name = Some "PyPI publish"
              , env = Some (toMap { MATURIN_PASSWORD = ghVar "secrets.PYPI" })
              , run = Some
                  "poetry run maturin publish --username __token__ --interpreter python${ghVar
                                                                                           "matrix.python_version"}"
              }
            ]
          }
        , bump = GithubActions.Job::{
          , name = Some "Bump minor version"
          , needs = Some [ "publish" ]
          , `if` = Some releaseCreatedCondition
          , runs-on = GithubActions.RunsOn.Type.ubuntu-latest
          , steps =
            [ GithubActions.steps.actions/checkout
            , setupPython latestPython
            , setupRust
            , installDeps DependencySet.Bump
            , GithubActions.Step::{
              , name = Some "Bump and push"
              , run = Some
                  ( Prelude.Text.concatSep
                      "\n"
                      [ "cargo bump patch"
                      , "poetry version patch"
                      , "git config user.name github-actions"
                      , "git config user.email github-actions@github.com"
                      , "git add Cargo.toml pyproject.toml"
                      , "git commit -m \"Bump version (automatic commit)\""
                      , "git push"
                      ]
                  )
              }
            ]
          }
        }
    }
