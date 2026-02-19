# BF6 Portal JSON Importer Walkthrough

## Installation

1.  **Extract the Zip**: Unzip `BF6PortalJsonImporter.zip`.
2.  **Copy Folder**: Drag and drop the `BF6PortalJsonImporter` folder into your Godot project's `addons/` directory.
    *   Path should look like: `res://addons/BF6PortalJsonImporter/`
3.  **Enable Plugin**:
    *   Open Godot.
    *   Go to **Project** -> **Project Settings**.
    *   Click the **Plugins** tab.
    *   Find **BF6 Portal JSON Importer** and check the **Enable** box.

## Usage

1.  **Open Dock**: The plugin adds a new dock tab named "BF6 Portal JSON Importer" (bottom-left by default).
2.  **Select Export**: Click **Browse** and select your `.json` export file (e.g., from the SDK export).
3.  **Rebuild**:
    *   Make sure you have a Scene open where you want the objects to appear.
    *   Click **Rebuild Scene**.
4.  **Result**: The plugin will create a new Node3D container with all the objects from the JSON, positioned correctly.

## Troubleshooting

-   **"Asset not found"**: Ensure your project has the object library in `res://objects/`. The plugin looks there recursively for `.tscn` files matching the JSON names.
-   **Plugin not showing**: Try reloading the project (Project -> Reload Current Project) after enabling it.
