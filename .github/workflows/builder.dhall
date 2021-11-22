let helpers = ./helpers.dhall

let GithubActions = helpers.GithubActions

let enums = helpers.enums

let constants = helpers.constants

let setup = helpers.setup

let OsConfig =
      { Type =
          { pythonExec : Text
          , container : Optional Text
          , runs-on : GithubActions.RunsOn.Type
          , pythonSetup : List GithubActions.Step.Type
          , interpreterArg : Text
          , strategy : Optional GithubActions.Strategy.Type
          , osName : Text
          , wheelsToInstall : Text
          }
      , default =
        { pythonExec = "python"
        , container = None Text
        , pythonSetup = [] : List GithubActions.Step.Type
        , interpreterArg = " --interpreter python${constants.matrixPython}"
        , strategy = Some GithubActions.Strategy::{
          , fail-fast = Some True
          , matrix = toMap { python-version = constants.supportedPythons }
          }
        }
      }

let osSpecificConfig =
      { Linux = OsConfig::{
        , pythonExec = "python${constants.matrixPython}"
        , container = Some constants.manylinuxContainer
        , runs-on = GithubActions.RunsOn.Type.ubuntu-latest
        , osName = "Linux"
        , wheelsToInstall = "target/wheels/dhall*manylinux*.whl"
        }
      , Mac = OsConfig::{
        , runs-on = GithubActions.RunsOn.Type.macos-latest
        , pythonSetup = [ setup.python constants.matrixPython ]
        , osName = "Mac"
        , wheelsToInstall = "target/wheels/dhall*.whl"
        }
      , Windows = OsConfig::{
        , runs-on = GithubActions.RunsOn.Type.windows-latest
        , interpreterArg = ""
        , strategy = None GithubActions.Strategy.Type
        , osName = "Windows"
        , wheelsToInstall = "--find-links=target\\wheels dhall"
        }
      }

let mainBuilder =
      λ(os : enums.SupportedOs) →
      λ(release : enums.ReleaseType) →
        let config = merge osSpecificConfig os

        let releaseStr = λ(x : Text) → merge { Release = x, Dev = "" } release

        let releaseCond =
              merge
                { Release = constants.releaseCreatedCondition
                , Dev = "!(${constants.releaseCreatedCondition})"
                }
                release

        in  GithubActions.Step::{
            , name = Some
                "Build and test python package${releaseStr " (Release)"}"
            , `if` = Some releaseCond
            , run = Some
                ( helpers.unlines
                    [ "${config.pythonExec} -m poetry run maturin build ${releaseStr
                                                                            "--release"} --strip${config.interpreterArg}"
                    , "${config.pythonExec} -m poetry run maturin develop"
                    , "${config.pythonExec} -m poetry run pytest tests"
                    ]
                )
            }

in  λ(os : enums.SupportedOs) →
      let config = merge osSpecificConfig os

      in  GithubActions.Job::{
          , name = Some "Build/test/publish ${config.osName}"
          , runs-on = config.runs-on
          , container = config.container
          , needs = Some [ "lint" ]
          , strategy = config.strategy
          , steps =
                config.pythonSetup
              # [ setup.rust
                , GithubActions.steps.actions/checkout
                , helpers.installDeps enums.DependencySet.Full config.pythonExec
                , mainBuilder os enums.ReleaseType.Dev
                , mainBuilder os enums.ReleaseType.Release
                , GithubActions.Step::{
                  , name = Some "Install wheels"
                  , run = Some
                      "${config.pythonExec} -m pip install ${config.wheelsToInstall}"
                  }
                , GithubActions.Step::{
                  , name = Some "Release"
                  , uses = Some "softprops/action-gh-release@v1"
                  , `if` = Some
                      "${constants.releaseTagCondition} && ${constants.releaseCreatedCondition}"
                  , `with` = Some (toMap { files = "target/wheels/dhall*.whl" })
                  , env = Some
                      ( toMap
                          { GITHUB_TOKEN = helpers.ghVar "secrets.GITHUB_TOKEN"
                          }
                      )
                  }
                , GithubActions.Step::{
                  , name = Some "PyPI publish"
                  , `if` = Some
                      "${constants.releaseTagCondition} && ${constants.releaseCreatedCondition}"
                  , env = Some
                      ( toMap
                          { MATURIN_PASSWORD = helpers.ghVar "secrets.PYPI" }
                      )
                  , run = Some
                      "${config.pythonExec} -m poetry run maturin publish --no-sdist --username __token__${config.interpreterArg}"
                  }
                ]
          }
