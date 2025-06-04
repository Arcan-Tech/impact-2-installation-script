#!/bin/bash

set -e

echo -e "

 _____                                _      ___                 _  _                    _____ 
|_   _|                              | |    / _ \               | |(_)                  / __  \\
  | |  _ __ ___   _ __    __ _   ___ | |_  / /_\ \ _ __    __ _ | | _  ___  _   _  ___  '  / /'
  | | | '_  ' _ \| '_ \  / _' | / __|| __| |  _  || '_ \  / _' || || |/ __|| | | |/ __|   / /  
 _| |_| | | | | || |_) || (_| || (__ | |_  | | | || | | || (_| || || |\__ \| |_| |\__ \ ./ /___
 \___/|_| |_| |_|| .__/  \__,_| \___| \__| \_| |_/|_| |_| \__,_||_||_||___/ \__, ||___/ \_____/
                 | |                                                         __/ |             
                 |_|                                                        |___/              

#### Impact Analysis 2 Installer ####
"

sed_wrap() {
  if sed --version 2>/dev/null | grep -q "GNU sed"; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

check_dependencies() {
    echo "Checking dependencies..."
    local missing_deps=0
    for cmd in git docker; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Error: Dependency '$cmd' is not installed. Please install it to proceed."
            missing_deps=1
        fi
    done

    if ! docker compose version &>/dev/null; then
        echo "Error: 'docker compose' (Docker Compose V2 plugin) is not available or not working."
        echo "Please ensure Docker Desktop or Docker Engine with Compose plugin is correctly installed."
        missing_deps=1
    fi

    if [ "$missing_deps" -eq 1 ]; then
        exit 1
    fi
    echo "All dependencies found."
}

check_docker_running() {
    echo "Checking Docker service..."
    if ! docker info &>/dev/null; then
        echo "Error: Docker is installed but the Docker daemon is not running."
        echo "Please start Docker and try again."
        exit 1
    fi
    echo "Docker service is running."
}

clone_or_update_repo() {
    local REPO_URL_BASE="https://github.com/Arcan-Tech/impact-infrastructure-2.git"
    local INSTALL_DIR_DEFAULT="./impact-infrastructure-2"
    local GIT_TOKEN=""
    local REPO_URL_TO_USE="$REPO_URL_BASE"

    read -p "Enter installation directory [default: $INSTALL_DIR_DEFAULT]: " INSTALL_DIR
    INSTALL_DIR="${INSTALL_DIR:-$INSTALL_DIR_DEFAULT}"

    read -p "GitHub Personal Access Token (PAT) for clone and registry (access to repo and packages): " GIT_TOKEN

    if [ -n "$GIT_TOKEN" ]; then
            REPO_URL_TO_USE="${REPO_URL_BASE/https:\/\//https:\/\/$GIT_TOKEN@}"
        else
            exit 1
            echo "No GitHub token provided. Exiting."
        fi

    if [ -d "$INSTALL_DIR/.git" ]; then
        echo "Existing repository found in $INSTALL_DIR."
        read -p "Do you want to update it (git pull)? [y/n]: " PULL_CHOICE
        PULL_CHOICE=$(echo "$PULL_CHOICE" | tr '[:upper:]' '[:lower:]')
        if [[ "$PULL_CHOICE" == "y" ]]; then
            echo "Updating repository in $INSTALL_DIR..."
            (
                cd "$INSTALL_DIR"

                if [ -n "$GIT_TOKEN" ]; then
                    echo "Temporarily setting remote URL with token for pull operation..."
                    git remote set-url origin "$REPO_URL_TO_USE"
                fi
                git fetch --all && git pull
            ) || { echo "Error updating repository. Please check for conflicts or issues."; exit 1; }
            echo "Repository updated."
        else
            echo "Skipping repository update."
        fi
    elif [ -d "$INSTALL_DIR" ] && [ "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
        echo "Error: Directory '$INSTALL_DIR' exists but is not a git repository and is not empty."
        echo "Please choose a different directory or clear its content."
        exit 1
    else
        echo "Cloning repository into $INSTALL_DIR..."
        mkdir -p "$INSTALL_DIR"
        git clone "$REPO_URL_TO_USE" "$INSTALL_DIR" || { echo "Error cloning repository."; rm -rf "$INSTALL_DIR"; exit 1; }
        echo "Repository cloned successfully."
    fi
    cd "$INSTALL_DIR"
    echo "Successfully set up repository in $(pwd)"
}

DOCKER_CONFIG_FILE_PATH="./config.json"
create_docker_config_json() {
    if [ -f "$DOCKER_CONFIG_FILE_PATH" ]; then
        echo "Docker config file ($DOCKER_CONFIG_FILE_PATH) already exists."
        read -p "Do you want to overwrite it? [y/n]: " OVERWRITE_DOCKER_CONFIG
        OVERWRITE_DOCKER_CONFIG=$(echo "$OVERWRITE_DOCKER_CONFIG" | tr '[:upper:]' '[:lower:]')
        if [[ "$OVERWRITE_DOCKER_CONFIG" != "y" ]]; then
            echo "Skipping Docker config.json creation."
            return
        fi
    fi

    GITHUB_DOCKER_TOKEN= $GIT_TOKEN

    if [ -z "$GITHUB_DOCKER_TOKEN" ]; then
        echo "GitHub token for ghcr.io not provided. Skipping $DOCKER_CONFIG_FILE_PATH creation."
        echo "Watchtower might not be able to update private images from ghcr.io."
        return
    fi

    local base64_cmd
    if base64 --version 2>/dev/null | grep -q "GNU coreutils"; then
        base64_cmd="base64 -w 0"
    else
        base64_cmd="base64"
    fi

    ENCODED_AUTH=$(echo -n "username:${GITHUB_DOCKER_TOKEN}" | $base64_cmd)

    cat >"$DOCKER_CONFIG_FILE_PATH" <<EOF
{
    "auths": {
        "ghcr.io": {
            "auth": "${ENCODED_AUTH}"
        }
    }
}
EOF
    echo "$DOCKER_CONFIG_FILE_PATH created successfully for ghcr.io authentication."
}


configure_installation_type() {
    echo "Select the type of environment to run:"
    echo "1) Snapshot"
    echo "2) Stable"
    read -p "Choice [1/2]: " ENV_CHOICE_INPUT

    INSTALL_TYPE_VAR=""
    ENV_FILE=""

    case $ENV_CHOICE_INPUT in
        1)
            INSTALL_TYPE_VAR="snapshot"
            ENV_FILE=".snapshot.env"
            if [ ! -f "$ENV_FILE" ]; then
                echo "Error: $ENV_FILE not found in the repository."
                echo "Please ensure the repository is correctly cloned/updated and the file exists."
                exit 1
            fi
            echo "Using snapshot environment with $ENV_FILE"
            ;;
        2)
            INSTALL_TYPE_VAR="stable"
            ENV_FILE=".stable.env"
            if [ ! -f "$ENV_FILE" ]; then
                echo "Error: $ENV_FILE not found in the repository."
                echo "Please ensure the repository is correctly cloned/updated and the file exists."
                exit 1
            fi
            echo "Using stable environment with $ENV_FILE"
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
}

replace_passwords_in_env() {
    local source_env_file="$1"
    local target_env_file=".env"

    if [ ! -f "$source_env_file" ]; then
        echo "Warning: Source environment file '$source_env_file' not found. Skipping .env setup and password generation."
        echo "If this is a release and .stable.env was missing in the tag, this is expected."
        echo "Ensure you have a correctly configured .env file before running the application."
        return
    fi
    echo "Copying '$source_env_file' to '$target_env_file' to be used as the active configuration."
    cp "$source_env_file" "$target_env_file"

    echo "The environment file '$target_env_file' (copied from '$source_env_file') may contain default passwords."
    read -p "Do you want to replace POSTGRES_PASSWORD and NEO4J_PASSWORD in '$target_env_file' with securely generated random passwords? (Recommended) [y/n]: " REPLACE_PASS
    REPLACE_PASS=$(echo "$REPLACE_PASS" | tr '[:upper:]' '[:lower:]')

    if [[ "$REPLACE_PASS" != "y" ]]; then
        echo "Skipping password replacement. Using passwords as defined in '$target_env_file'."
        return
    fi

    echo "Proceeding to replace passwords in '$target_env_file'."
    cp "$target_env_file" "${target_env_file}.bak.$(date +%s)"
    echo "Backup of '$target_env_file' saved as '${target_env_file}.bak....'"

    local modified=0
    if grep -q "^POSTGRES_PASSWORD=" "$target_env_file"; then
        new_pg_pass=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 20)
        sed_wrap "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${new_pg_pass}|" "$target_env_file"
        echo "POSTGRES_PASSWORD updated in '$target_env_file'."
        modified=1
    else
        echo "POSTGRES_PASSWORD not found in '$target_env_file'."
    fi

    if grep -q "^NEO4J_PASSWORD=" "$target_env_file"; then
        new_neo_pass=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 20)
        sed_wrap "s|^NEO4J_PASSWORD=.*|NEO4J_PASSWORD=${new_neo_pass}|" "$target_env_file"
        echo "NEO4J_PASSWORD updated in '$target_env_file'."
        modified=1
    else
        echo "NEO4J_PASSWORD not found in '$target_env_file'."
    fi

    if [ "$modified" -eq 1 ]; then
        echo "Passwords updated in '$target_env_file'. Note: If DATABASE_URL (or similar) uses these passwords, it should reference them via \${VAR_NAME} to pick up changes."
    else
        echo "No passwords were found or updated in '$target_env_file'."
    fi
}

create_required_dirs() {
    echo "Creating required directories..."
    mkdir -p ./logs
    echo "Directory ./logs created/ensured."
}

generate_run_script() {
    local run_script_name="run-impact-2.sh"
    local install_type_param="$1"

    local docker_compose_base_cmd="docker compose"
    local final_docker_compose_cmd="$docker_compose_base_cmd"

    echo "Generating run script: $run_script_name ..."
    cat > "$run_script_name" <<EOF
#!/bin/bash

set -e
echo "Starting Impact Infrastructure 2 (snapshot environment)..."

if [[ "$(uname)" == "Darwin" ]]; then
    echo "Running on macOS. MY_UID=\$MY_UID, MY_GID=\$MY_GID"
    EFFECTIVE_USER=$(id -un)
    DOCKER_HOST=unix:///Users/\$EFFECTIVE_USER/.docker/run/docker.sock MY_UID="$(id -u)" MY_GID="$(id -g)" docker --config ./docker-conf compose up \$@
else
    echo "Running on Linux or other Unix-like OS. MY_UID=\$MY_UID, MY_GID=\$MY_GID"
    MY_UID="$(id -u)" MY_GID="$(id -g)" docker --config ./docker-conf compose up \$@
fi
EOF

    chmod +x "$run_script_name"
    echo "$run_script_name created successfully."
    echo "You can start the application using: ./$run_script_name"
    echo "Use './$run_script_name -d' to run in detached mode."
}


check_dependencies
check_docker_running
clone_or_update_repo
create_docker_config_json
configure_installation_type
replace_passwords_in_env "$ENV_FILE"
create_required_dirs
generate_run_script "$INSTALL_TYPE_VAR"

echo ""
echo "-----------------------------------------------------"
echo "Impact Infrastructure 2 installation process complete!"
echo "-----------------------------------------------------"
echo ""
echo "The application will use the '.env' file for its configuration."
echo "If you chose to generate random passwords, they are in '.env'."
echo ""
echo "To start the application, navigate to $(pwd) and run:"
echo "  ./run-impact-2.sh"
echo ""
echo "To run in detached mode (background):"
echo "  ./run-impact-2.sh -d"
echo ""
echo "To view logs:"
echo "  ./run-impact-2.sh logs -f"
echo ""
echo "To stop the application (from the same directory):"
echo "  docker compose down" # docker compose down will also use .env if present
echo ""
echo "Enjoy using Impact Infrastructure 2!"