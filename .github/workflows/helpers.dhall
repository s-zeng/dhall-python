let GithubActions =
      https://raw.githubusercontent.com/regadas/github-actions-dhall/04e304c2a73cb3dcdd77449f807ad259128e0d5c/package.dhall
        sha256:3af4c42342006a960fde1018fbcbe3333abd0fd3b108c0888f7cd5ff35937032

let Prelude =
      https://prelude.dhall-lang.org/v21.1.0/package.dhall
        sha256:0fed19a88330e9a8a3fbe1e8442aa11d12e38da51eb12ba8bcb56f3c25d0854a

let unlines = Prelude.Text.concatSep "\n"

let ghVar = λ(varName : Text) → "\${{ ${varName} }}"

let constants =
      { latestPython = "3.10"
      , matrixPython = ghVar "matrix.python-version"
      , manylinuxContainer = "quay.io/pypa/manylinux_2_24_x86_64"
      , supportedPythons = [ "3.7", "3.8", "3.9", "3.10", "3.11" ]
      , releaseCreatedCondition =
          "github.event_name == 'release' && github.event.action == 'created'"
      , releaseTagCondition = "startsWith(github.ref, 'refs/tags/')"
      }

let enums =
      { DependencySet = < Full | Lint | Bump >
      , SupportedOs = < Windows | Mac | Linux >
      , ReleaseType = < Release | Dev >
      }

let setup =
      { dhall = GithubActions.Step::{
        , uses = Some "dhall-lang/setup-dhall@v4"
        , name = Some "Install dhall"
        , `with` = Some (toMap { version = "1.41.1" })
        }
      , python =
          λ(version : Text) →
            GithubActions.Step::{
            , uses = Some "actions/setup-python@v3"
            , name = Some "Setup python ${version}"
            , `with` = Some (toMap { python-version = version })
            }
      , rust = GithubActions.Step::{
        , uses = Some "actions-rs/toolchain@v1"
        , name = Some "Install Rust"
        , `with` = Some (toMap { toolchain = "stable", override = "true" })
        }
      }

let installDeps =
      λ(installType : enums.DependencySet) →
      λ(pythonExec : Text) →
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

in  { unlines
    , ghVar
    , constants
    , enums
    , setup
    , GithubActions
    , Prelude
    , installDeps
    }
