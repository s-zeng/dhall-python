let GithubActions =
      https://raw.githubusercontent.com/regadas/github-actions-dhall/master/package.dhall
        sha256:66b276bb67cca4cfcfd1027da45857cc8d53e75ea98433b15dade1e1e1ec22c8

let Prelude =
      https://prelude.dhall-lang.org/v21.0.0/package.dhall
        sha256:46c48bba5eee7807a872bbf6c3cb6ee6c2ec9498de3543c5dcc7dd950e43999d

let unlines = Prelude.Text.concatSep "\n"

let ghVar
    : Text -> Text
    = \(varName : Text) -> "\${{ ${varName} }}"

let setup =
      { dhall = GithubActions.Step::{
        , uses = Some "dhall-lang/setup-dhall@v4"
        , name = Some "Install dhall"
        , `with` = Some (toMap { version = "1.40.1" })
        }
      , python =
          \(version : Text) ->
            GithubActions.Step::{
            , uses = Some "actions/setup-python@v2"
            , name = Some "Setup python ${version}"
            , `with` = Some (toMap { python-version = version })
            }
      , rust = GithubActions.Step::{
        , uses = Some "actions-rs/toolchain@v1"
        , name = Some "Install Rust"
        , `with` = Some (toMap { toolchain = "stable", override = "true" })
        }
      }

let DependencySet = < Full | Lint | Bump >

let installDeps =
      \(installType : DependencySet) ->
      \(pyversion : Text) ->
        let fullDeps =
              [ "python${pyversion} -m pip install poetry"
              , "touch Cargo.toml.orig"
              , "python${pyversion} -m poetry install"
              ]

        let deps =
              merge
                { Full = fullDeps
                , Lint =
                  [ "python${pyversion} -m pip install black isort autoflake" ]
                , Bump = [ "cargo install cargo-bump" ] # fullDeps
                }
                installType

        in  GithubActions.Step::{
            , name = Some "Install dependencies"
            , run = Some
                ( unlines
                    (   [ "python${pyversion} -m pip install --upgrade pip" ]
                      # deps
                    )
                )
            }

let latestPython = "3.10"

let matrixPython = ghVar "matrix.python-version"

let supportedManylinux = "2_24"

let supportedLinuxArch = "x86_64"

let manylinuxContainer =
      "quay.io/pypa/manylinux_${supportedManylinux}_${supportedLinuxArch}"

let supportPythons = [ "3.6", "3.7", "3.8", "3.9", "3.10" ]

let supportedOSs = [ "macos-latest", "windows-latest" ]

let releaseCreatedCondition =
      "github.event_name == 'release' && github.event.action == 'created'"

let manylinuxify =
      \(job : GithubActions.Job.Type) ->
            job
        //  { name =
                Prelude.Optional.map
                  Text
                  Text
                  (\(n : Text) -> n ++ " (manylinux)")
                  job.name
            , container = Some manylinuxContainer
            , strategy = Some GithubActions.Strategy::{
              , fail-fast = Some True
              , matrix = toMap
                  { os = [ "ubuntu-latest" ], python-version = supportPythons }
              }
            , steps =
                  Prelude.List.take 1 GithubActions.Step.Type job.steps
                # Prelude.List.drop 2 GithubActions.Step.Type job.steps
            }

let builder =
      GithubActions.Job::{
      , name = Some "Build/test wheels"
      , runs-on = GithubActions.RunsOn.Type.`${{ matrix.os }}`
      , needs = Some [ "lint" ]
      , `if` = Some "github.event.name != 'release'"
      , strategy = Some GithubActions.Strategy::{
        , fail-fast = Some True
        , matrix = toMap { os = supportedOSs, python-version = supportPythons }
        }
      , steps =
        [ GithubActions.steps.actions/checkout
        , setup.python matrixPython
        , setup.rust
        , installDeps DependencySet.Full matrixPython
        , GithubActions.Step::{
          , name = Some "Maturin build and pytest"
          , run = Some
              ( unlines
                  [ "python${matrixPython} -m poetry run maturin build --interpreter python${matrixPython}"
                  , "python${matrixPython} -m poetry run maturin develop --interpreter python${matrixPython}"
                  , "python${matrixPython} -m poetry run pytest tests --interpreter python${matrixPython}"
                  ]
              )
          }
        ]
      }

let publisher =
      GithubActions.Job::{
      , name = Some "Publish wheels to PyPI"
      , runs-on = GithubActions.RunsOn.Type.`${{ matrix.os }}`
      , needs = Some [ "macWindowsBuild", "manylinuxBuild" ]
      , `if` = Some releaseCreatedCondition
      , strategy = Some GithubActions.Strategy::{
        , fail-fast = Some True
        , matrix = toMap { os = supportedOSs, python-version = supportPythons }
        }
      , steps =
        [ GithubActions.steps.actions/checkout
        , setup.python matrixPython
        , setup.rust
        , installDeps DependencySet.Full matrixPython
        , GithubActions.Step::{
          , name = Some "Build python package"
          , run = Some
              "python${matrixPython} -m poetry run maturin build --release --strip --interpreter python${matrixPython}"
          }
        , GithubActions.Step::{
          , name = Some "Install wheels"
          , `if` = Some "matrix.os == 'windows-latest'"
          , run = Some
              "python${matrixPython} -m pip install --find-links=target\\wheels dhall"
          }
        , GithubActions.Step::{
          , name = Some "Install wheels"
          , `if` = Some "matrix.os != 'windows-latest'"
          , run = Some
              "python${matrixPython} -m pip install target/wheels/dhall*.whl"
          }
        , GithubActions.Step::{
          , name = Some "Release"
          , uses = Some "softprops/action-gh-release@v1"
          , `if` = Some "startsWith(github.ref, 'refs/tags/')"
          , `with` = Some (toMap { files = "target/wheels/dhall*.whl" })
          , env = Some (toMap { GITHUB_TOKEN = ghVar "secrets.GITHUB_TOKEN" })
          }
        , GithubActions.Step::{
          , name = Some "PyPI publish"
          , env = Some (toMap { MATURIN_PASSWORD = ghVar "secrets.PYPI" })
          , run = Some
              "python${matrixPython} -m poetry run maturin publish --username __token__ --interpreter python${ghVar
                                                                                                                "matrix.python_version"}"
          }
        ]
      }

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
            , setup.python latestPython
            , setup.dhall
            , installDeps DependencySet.Lint latestPython
            , GithubActions.Step::{
              , name = Some "Check github actions workflow"
              , `if` = Some "github.event.name != 'pull_request'"
              , run = Some
                  ( unlines
                      [ "dhall-to-yaml < .github/workflows/ci.dhall > expected.yml"
                      , "diff expected.yml .github/workflows/ci.yml"
                      ]
                  )
              }
            , GithubActions.Step::{
              , name = Some "Check lint"
              , run = Some
                  (unlines [ "isort . --check --diff", "black . --check" ])
              }
            ]
          }
        , macWindowsBuild = builder
        , manylinuxBuild = manylinuxify builder
        , macWindowsPublish = publisher
        , manylinuxPublish = manylinuxify publisher
        , bump = GithubActions.Job::{
          , name = Some "Bump minor version"
          , needs = Some [ "macWindowsPublish", "manylinuxPublish" ]
          , `if` = Some releaseCreatedCondition
          , runs-on = GithubActions.RunsOn.Type.ubuntu-latest
          , steps =
            [ GithubActions.steps.actions/checkout
            , setup.python latestPython
            , setup.rust
            , installDeps DependencySet.Bump latestPython
            , GithubActions.Step::{
              , name = Some "Bump and push"
              , run = Some
                  ( unlines
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
