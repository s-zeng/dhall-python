let helpers = ./helpers.dhall

let builder = ./builder.dhall

let GithubActions = helpers.GithubActions

let enums = helpers.enums

let constants = helpers.constants

let setup = helpers.setup

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
            , setup.dhall
            , GithubActions.Step::{
              , name = Some "Check github actions workflow"
              , `if` = Some "github.event.name != 'pull_request'"
              , run = Some
                  ( helpers.unlines
                      [ "dhall lint .github/workflows/*.dhall"
                      , "yaml-to-dhall ./.github/workflows/schema.dhall < .github/workflows/ci.yml > expected.dhall"
                      , "dhall diff ./expected.dhall ./.github/workflows/ci.dhall"
                      ]
                  )
              }
            , setup.python constants.latestPython
            , helpers.installDeps enums.DependencySet.Lint "python"
            , GithubActions.Step::{
              , name = Some "Check lint"
              , run = Some
                  ( helpers.unlines
                      [ "isort . --check --diff", "black . --check" ]
                  )
              }
            ]
          }
        , macBuild = builder enums.SupportedOs.Mac
        , windowsBuild = builder enums.SupportedOs.Windows
        , linuxBuild = builder enums.SupportedOs.Linux
        , bump = GithubActions.Job::{
          , name = Some "Bump minor version"
          , needs = Some [ "lint" ]
          , `if` = Some constants.releaseCreatedCondition
          , runs-on = GithubActions.RunsOn.Type.ubuntu-latest
          , steps =
            [   GithubActions.steps.actions/checkout
              ⫽ { `with` = Some (toMap { ref = "master" }) }
            , setup.python constants.latestPython
            , setup.rust
            , helpers.installDeps enums.DependencySet.Bump "python"
            , GithubActions.Step::{
              , name = Some "Bump and push"
              , run = Some
                  ( helpers.unlines
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
