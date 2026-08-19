#!/bin/bash
set -uo pipefail

# This hook runs before chezmoi reads and renders its source state, on EVERY
# chezmoi command. It must never exit non-zero: a failure here used to abort
# every apply. Failures are reported to stderr only (the setup-failures log
# is reset later in the run, so it is not used here).
nudge='No active 1Password session. Encrypted files (AI skills and credentials) will be skipped. Sign in with: eval "$(op signin)"  then run: chezmoi apply'
skip_note='Encrypted files (AI skills and credentials) will be skipped.'

key_dir="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
identity_file="$key_dir/age-identity.txt"
recipient_file="$key_dir/age-recipient.txt"

# Fast path: keys already fetched. Delete either file to force a refetch.
if [[ -s "$identity_file" && -s "$recipient_file" ]]; then
    exit 0
fi

if ! command -v op >/dev/null 2>&1; then
    case "$(uname -s)" in
    Darwin)
        if command -v brew >/dev/null 2>&1; then
            brew_bin="$(command -v brew)"
        elif [[ -x /opt/homebrew/bin/brew ]]; then
            brew_bin=/opt/homebrew/bin/brew
        elif [[ -x /usr/local/bin/brew ]]; then
            brew_bin=/usr/local/bin/brew
        else
            if ! xcode-select -p >/dev/null 2>&1; then
                echo "Xcode Command Line Tools are required for the 1Password CLI. Install with 'xcode-select --install'." >&2
                echo "$nudge" >&2
                exit 0
            fi
            if ! NONINTERACTIVE=1 /bin/bash -c \
                "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
                echo "Homebrew install failed." >&2
                echo "$nudge" >&2
                exit 0
            fi
            if [[ -x /opt/homebrew/bin/brew ]]; then
                brew_bin=/opt/homebrew/bin/brew
            else
                brew_bin=/usr/local/bin/brew
            fi
        fi
        if ! "$brew_bin" install 1password-cli; then
            echo "1Password CLI install failed." >&2
            echo "$nudge" >&2
            exit 0
        fi
        ;;
    Linux)
        if command -v apt-get >/dev/null 2>&1; then
            if ! {
                sudo apt-get update \
                    && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg \
                    && sudo install -d -m 0755 /usr/share/keyrings \
                    && curl -fsSL https://downloads.1password.com/linux/keys/1password.asc \
                        | sudo gpg --batch --yes --dearmor \
                            --output /usr/share/keyrings/1password-archive-keyring.gpg \
                    && printf '%s\n' \
                        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
                        | sudo tee /etc/apt/sources.list.d/1password.list >/dev/null \
                    && sudo install -d -m 0755 /etc/debsig/policies/AC2D62742012EA22 \
                    && curl -fsSL https://downloads.1password.com/linux/debian/debsig/1password.pol \
                        | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol >/dev/null \
                    && sudo install -d -m 0755 /usr/share/debsig/keyrings/AC2D62742012EA22 \
                    && curl -fsSL https://downloads.1password.com/linux/keys/1password.asc \
                        | sudo gpg --batch --yes --dearmor \
                            --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg \
                    && sudo apt-get update \
                    && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y 1password-cli
            }; then
                echo "1Password CLI install failed." >&2
                echo "$nudge" >&2
                exit 0
            fi
        elif command -v dnf >/dev/null 2>&1; then
            if ! {
                sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc \
                    && printf '%s\n' \
                        '[1password]' \
                        'name=1Password Stable Channel' \
                        'baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch' \
                        'enabled=1' \
                        'gpgcheck=1' \
                        'repo_gpgcheck=1' \
                        'gpgkey=https://downloads.1password.com/linux/keys/1password.asc' \
                        | sudo tee /etc/yum.repos.d/1password.repo >/dev/null \
                    && sudo dnf install -y 1password-cli
            }; then
                echo "1Password CLI install failed." >&2
                echo "$nudge" >&2
                exit 0
            fi
        else
            echo "Automatic early 1Password CLI installation supports apt, dnf, and macOS." >&2
            echo "$nudge" >&2
            exit 0
        fi
        ;;
    *)
        echo "Unsupported OS for automatic 1Password CLI installation: $(uname -s)" >&2
        echo "$nudge" >&2
        exit 0
        ;;
    esac
fi

if ! op whoami >/dev/null 2>&1; then
    echo "$nudge" >&2
    exit 0
fi

if ! install -d -m 0700 "$key_dir"; then
    echo "Cannot create $key_dir." >&2
    echo "$skip_note" >&2
    exit 0
fi

if ! identity_tmp="$(mktemp "$key_dir/.age-identity.XXXXXX")" \
    || ! recipient_tmp="$(mktemp "$key_dir/.age-recipient.XXXXXX")"; then
    echo "Cannot create temporary key files." >&2
    echo "$skip_note" >&2
    exit 0
fi
trap 'rm -f "$identity_tmp" "$recipient_tmp"' EXIT
chmod 0600 "$identity_tmp" "$recipient_tmp"

if ! op read 'op://Personal/chezmoi-age-identity/age-identity.txt' > "$identity_tmp" \
    || ! op read 'op://Personal/chezmoi-age-identity/recipient' > "$recipient_tmp"; then
    echo "Reading the 1Password age identity/recipient failed." >&2
    echo "$skip_note" >&2
    exit 0
fi

if ! grep -q '^AGE-SECRET-KEY-' "$identity_tmp"; then
    echo "The 1Password age identity does not contain an AGE-SECRET-KEY entry." >&2
    echo "$skip_note" >&2
    exit 0
fi

if ! grep -Eq '^age1[0-9a-z]+$' "$recipient_tmp"; then
    echo "The 1Password age recipient is not a valid age1 recipient." >&2
    echo "$skip_note" >&2
    exit 0
fi

if ! mv "$identity_tmp" "$identity_file" || ! mv "$recipient_tmp" "$recipient_file"; then
    echo "Cannot write the age key files." >&2
    echo "$skip_note" >&2
    exit 0
fi
trap - EXIT
exit 0
