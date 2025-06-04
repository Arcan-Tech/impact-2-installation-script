# Impact Analysis 2 Installer

This script automates the download and initial setup of the Impact Analysis 2 application.

## How to Use

1.  **Clone this repo:**
    ```bash
    git clone https://github.com/Arcan-Tech/impact-2-installation-script.git
    ```

2.  **Make it Executable:**
    ```bash
    chmod +x install.sh
    ```

3.  **Run the Script:**
    ```bash
    ./install.sh
    ```

4.  **Follow Prompts:**
    The script will ask for:
    *   The desired **installation directory**.
    *   Your **GitHub Personal Access Token (PAT)** (required for cloning the private repository and accessing private Docker images).
    *   The **environment type** (Snapshot or Stable).
    *   Whether to **regenerate default passwords** in the environment file.

## What the Script Creates

In the chosen installation directory, the script will set up the following:

*   **Application Source Code:** The `impact-infrastructure-2` repository will be cloned into this directory.
*   **`config.json`:** A Docker configuration file for authenticating with `ghcr.io` (GitHub Container Registry), enabling private image pulls. (Located at the root of the cloned repo).
*   **`.env`:** The active environment configuration file used by Docker Compose. This is a copy of either `.snapshot.env` or `.stable.env`, potentially with updated passwords.
*   **`logs/` directory:** A subdirectory created to store application logs.
*   **`run-impact-2.sh`:** An executable script to easily start the Impact Infrastructure 2 application using Docker Compose.
*   **`.env.bak.TIMESTAMP` (Optional):** If you choose to regenerate passwords, a backup of the original `.env` file is created before modification.

After running, navigate to the installation directory and use `./run-impact-2.sh` to start the application.