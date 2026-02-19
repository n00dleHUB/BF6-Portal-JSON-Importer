# BF6 Portal JSON Importer

A Godot 4 addon for importing JSON scene data exported from the Battlefield 6 Portal SDK.

## Installation

### Option 1: Download from GitHub (Recommended)
1.  Go to the [Releases](https://github.com/n00dleHUB/BF6-Portal-JSON-Importer/releases) page (if available) or click the green **Code** button and select **Download ZIP**.
2.  Extract the ZIP file.
3.  Copy the folder `BF6PortalJsonImporter` into your Godot project's `addons/` directory.
    -   **Important**: The path must be `res://addons/BF6PortalJsonImporter/`. Make sure you don't have nested folders (e.g., `addons/BF6-Portal-JSON-Importer-main/BF6PortalJsonImporter/`).

### Option 2: Clone via Git
Navigate to your project's `addons` folder and run:
```bash
git clone https://github.com/n00dleHUB/BF6-Portal-JSON-Importer.git BF6PortalJsonImporter
```

## Enable Plugin
1.  Open your Godot project.
2.  Go to **Project** -> **Project Settings**.
3.  Click the **Plugins** tab.
4.  Find **BF6 Portal JSON Importer** and check the **Enable** box.

## Usage

1.  **Open Dock**: The plugin adds a dock tab named "BF6 Portal JSON Importer" (bottom-left by default).
2.  **Select Export**: Click **Browse** and select your `.json` export file from the SDK.
3.  **Rebuild**:
    -   Ensure you have the scene open where you want the objects.
    -   Click **Rebuild Scene**.
4.  **Result**: A new `Node3D` container will be created with all objects positioned correctly.

## Requirements

-   **Godot 4.x**
-   **Object Library**: Your project must have the corresponding `.tscn` files in `res://objects/`. The importer searches recursively for filenames matching the JSON entries.
