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
      \(pythonExec : Text) ->
        let fullDeps =
              [ "${pythonExec} -m pip install poetry"
              , "touch Cargo.toml.orig"
              , "${pythonExec} -m poetry install"
              ]

        let deps =
              merge
                { Full = fullDeps
                , Lint =
                  [ "${pythonExec} -m pip install black isort autoflake" ]
                , Bump = [ "cargo install cargo-bump" ] # fullDeps
                }
                installType

        in  GithubActions.Step::{
            , name = Some "Install dependencies"
            , run = Some
                ( unlines
                    ([ "${pythonExec} -m pip install --upgrade pip" ] # deps)
                )
            }

let latestPython = "3.10"

let matrixPython = ghVar "matrix.python-version"

let supportedManylinux = "2_24"

let supportedLinuxArch = "x86_64"

let manylinuxContainer =
      "quay.io/pypa/manylinux_${supportedManylinux}_${supportedLinuxArch}"

let supportPythons = [ "3.6", "3.7", "3.8", "3.9", "3.10" ]

let SupportedOs = < Windows | Mac | Linux >

let releaseCreatedCondition =
      "github.event_name == 'release' && github.event.action == 'created'"

let builder =
      \(os : SupportedOs) ->
        let pythonExec =
              merge
                { Linux = "python${matrixPython}"
                , Mac = "python"
                , Windows = "python"
                }
                os

        let container =
              merge
                { Linux = Some manylinuxContainer
                , Mac = None Text
                , Windows = None Text
                }
                os

        let runningOs =
              merge
                { Linux = GithubActions.RunsOn.Type.ubuntu-latest
                , Mac = GithubActions.RunsOn.Type.macos-latest
                , Windows = GithubActions.RunsOn.Type.windows-latest
                }
                os

        let pythonSetup =
              merge
                { Linux = [] : List GithubActions.Step.Type
                , Mac = [ setup.python matrixPython ]
                , Windows = [ setup.python matrixPython ]
                }
                os

        let interpreterArg =
              merge
                { Linux = " --interpreter python${matrixPython}"
                , Mac = " --interpreter python${matrixPython}"
                , Windows = ""
                }
                os

        let osName =
              merge { Linux = "Linux", Mac = "Mac", Windows = "Windows" } os

        let mainBuilder =
              \(release : Bool) ->
                GithubActions.Step::{
                , name = Some "Build and test python package"
                , `if` = Some
                    ( if    release
                      then  releaseCreatedCondition
                      else  "!(${releaseCreatedCondition})"
                    )
                , run = Some
                    ( unlines
                        [ "${pythonExec} -m poetry run maturin build ${if    release
                                                                       then  "--release"
                                                                       else  ""} --strip${interpreterArg}"
                        , "${pythonExec} -m poetry run maturin develop"
                        , "${pythonExec} -m poetry run pytest tests"
                        ]
                    )
                }

        let installer =
              merge
                { Linux = GithubActions.Step::{
                  , name = Some "Install wheels"
                  , run = Some
                      "${pythonExec} -m pip install target/wheels/dhall*.whl"
                  }
                , Mac = GithubActions.Step::{
                  , name = Some "Install wheels"
                  , run = Some
                      "${pythonExec} -m pip install target/wheels/dhall*.whl"
                  }
                , Windows = GithubActions.Step::{
                  , name = Some "Install wheels"
                  , run = Some
                      "${pythonExec} -m pip install --find-links=target\\wheels dhall"
                  }
                }
                os

        in  GithubActions.Job::{
            , name = Some "Build/test/publish ${osName}"
            , runs-on = runningOs
            , container
            , needs = Some [ "lint" ]
            , strategy = Some GithubActions.Strategy::{
              , fail-fast = Some True
              , matrix = toMap { python-version = supportPythons }
              }
            , steps =
                  pythonSetup
                # [ setup.rust
                  , GithubActions.steps.actions/checkout
                  , installDeps DependencySet.Full pythonExec
                  , mainBuilder False
                  , mainBuilder True
                  , installer
                  , GithubActions.Step::{
                    , name = Some "Release"
                    , uses = Some "softprops/action-gh-release@v1"
                    , `if` = Some
                        "startsWith(github.ref, 'refs/tags/') && ${releaseCreatedCondition}"
                    , `with` = Some
                        (toMap { files = "target/wheels/dhall*.whl" })
                    , env = Some
                        (toMap { GITHUB_TOKEN = ghVar "secrets.GITHUB_TOKEN" })
                    }
                  , GithubActions.Step::{
                    , name = Some "PyPI publish"
                    , `if` = Some
                        "startsWith(github.ref, 'refs/tags/') && ${releaseCreatedCondition}"
                    , env = Some
                        (toMap { MATURIN_PASSWORD = ghVar "secrets.PYPI" })
                    , run = Some
                        "${pythonExec} -m poetry run maturin publish --username __token__${interpreterArg}"
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
            , installDeps DependencySet.Lint "python"
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
        , macBuild = builder SupportedOs.Mac
        , windowsBuild = builder SupportedOs.Windows
        , linuxBuild = builder SupportedOs.Linux
        , bump = GithubActions.Job::{
          , name = Some "Bump minor version"
          , needs = Some [ "lint" ]
          , `if` = Some releaseCreatedCondition
          , runs-on = GithubActions.RunsOn.Type.ubuntu-latest
          , steps =
            [ GithubActions.steps.actions/checkout
            , setup.python latestPython
            , setup.rust
            , installDeps DependencySet.Bump "python"
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
