let GithubActions =
      https://raw.githubusercontent.com/regadas/github-actions-dhall/83be7a912cf81b80197897bc250ba38019d130c0/package.dhall
        sha256:98ee16e6add21cc8ea7804cce55793b8793b14479f248d8f0bda0209d3600e18

let Prelude =
      https://prelude.dhall-lang.org/v21.0.0/package.dhall
        sha256:46c48bba5eee7807a872bbf6c3cb6ee6c2ec9498de3543c5dcc7dd950e43999d

let unlines = Prelude.Text.concatSep "\n"

let ghVar = λ(varName : Text) → "\${{ ${varName} }}"

let constants =
      { latestPython = "3.10"
      , matrixPython = ghVar "matrix.python-version"
      , manylinuxContainer = "quay.io/pypa/manylinux_2_24_x86_64"
      , supportedPythons = [ "3.7", "3.8", "3.9", "3.10" ]
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
        , `with` = Some (toMap { version = "1.40.1" })
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
