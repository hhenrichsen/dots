#!/bin/bash
set -euo pipefail

# This hook runs before chezmoi reads and renders its source state. Install the
# 1Password CLI first, then materialize the age key files if they are absent.
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
            echo "Install Xcode Command Line Tools with 'xcode-select --install', then retry." >&2
            exit 1
        fi
        NONINTERACTIVE=1 /bin/bash -c \
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [[ -x /opt/homebrew/bin/brew ]]; then
            brew_bin=/opt/homebrew/bin/brew
        else
            brew_bin=/usr/local/bin/brew
        fi
    fi
    "$brew_bin" install 1password-cli
    ;;
Linux)
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg

        sudo install -d -m 0755 /usr/share/keyrings
        curl -fsSL https://downloads.1password.com/linux/keys/1password.asc \
            | sudo gpg --batch --yes --dearmor \
                --output /usr/share/keyrings/1password-archive-keyring.gpg

        printf '%s\n' \
            "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
            | sudo tee /etc/apt/sources.list.d/1password.list >/dev/null

        sudo install -d -m 0755 /etc/debsig/policies/AC2D62742012EA22
        curl -fsSL https://downloads.1password.com/linux/debian/debsig/1password.pol \
            | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol >/dev/null

        sudo install -d -m 0755 /usr/share/debsig/keyrings/AC2D62742012EA22
        curl -fsSL https://downloads.1password.com/linux/keys/1password.asc \
            | sudo gpg --batch --yes --dearmor \
                --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg

        sudo apt-get update
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y 1password-cli
    elif command -v dnf >/dev/null 2>&1; then
        sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
        printf '%s\n' \
            '[1password]' \
            'name=1Password Stable Channel' \
            'baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch' \
            'enabled=1' \
            'gpgcheck=1' \
            'repo_gpgcheck=1' \
            'gpgkey=https://downloads.1password.com/linux/keys/1password.asc' \
            | sudo tee /etc/yum.repos.d/1password.repo >/dev/null
        sudo dnf install -y 1password-cli
    else
        echo "Automatic early 1Password CLI installation supports apt, dnf, and macOS." >&2
        exit 1
    fi
    ;;
*)
    echo "Unsupported OS for automatic 1Password CLI installation: $(uname -s)" >&2
    exit 1
    ;;
esac
fi

key_dir="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
identity_file="$key_dir/age-identity.txt"
recipient_file="$key_dir/age-recipient.txt"

# Keep the common path fast. Delete either file to fetch a rotated value.
if [[ -s "$identity_file" && -s "$recipient_file" ]]; then
    exit 0
fi

install -d -m 0700 "$key_dir"

identity_tmp="$(mktemp "$key_dir/.age-identity.XXXXXX")"
recipient_tmp="$(mktemp "$key_dir/.age-recipient.XXXXXX")"
trap 'rm -f "$identity_tmp" "$recipient_tmp"' EXIT
chmod 0600 "$identity_tmp" "$recipient_tmp"

op read 'op://Personal/chezmoi-age-identity/age-identity.txt' > "$identity_tmp"
op read 'op://Personal/chezmoi-age-identity/recipient' > "$recipient_tmp"

if ! grep -q '^AGE-SECRET-KEY-' "$identity_tmp"; then
    echo "The 1Password age identity does not contain an AGE-SECRET-KEY entry." >&2
    exit 1
fi

if ! grep -Eq '^age1[0-9a-z]+$' "$recipient_tmp"; then
    echo "The 1Password age recipient is not a valid age1 recipient." >&2
    exit 1
fi

mv "$identity_tmp" "$identity_file"
mv "$recipient_tmp" "$recipient_file"
trap - EXIT
