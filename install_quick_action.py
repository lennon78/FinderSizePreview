import plistlib
import os
import argparse

def install_action(app_path):
    workflow_name = "Preview File Size.workflow"
    workflow_dir = os.path.expanduser(f"~/Library/Services/{workflow_name}")
    os.makedirs(os.path.join(workflow_dir, "Contents"), exist_ok=True)

    wflow = {
        "AMApplicationBuild": "521.1",
        "AMApplicationVersion": "2.10",
        "AMDocumentVersion": "2",
        "actions": [
            {
                "action": {
                    "AMAccepts": {
                        "Container": "List",
                        "Optional": True,
                        "Types": ["com.apple.cocoa.path"]
                    },
                    "AMActionVersion": "2.0.3",
                    "AMParameterProperties": {
                        "COMMAND_STRING": {"isPathPopUp": False},
                        "CheckedForUserDefaultShell": {"isPathPopUp": False},
                        "inputMethod": {"isPathPopUp": False},
                        "shell": {"isPathPopUp": False},
                        "source": {"isPathPopUp": False}
                    },
                    "AMProvides": {
                        "Container": "List",
                        "Types": ["com.apple.cocoa.string"]
                    },
                    "ActionBundlePath": "/System/Library/Automator/Run Shell Script.action",
                    "ActionName": "Run Shell Script",
                    "ActionParameters": {
                        "COMMAND_STRING": f'open -na "{app_path}" "$@"',
                        "CheckedForUserDefaultShell": True,
                        "inputMethod": 1,
                        "shell": "/bin/bash",
                        "source": ""
                    },
                    "BundleIdentifier": "com.apple.RunScript",
                    "CFBundleVersion": "2.0.3",
                    "XCBuildConfigurationIdentifier": "com.apple.Automator.RunScript",
                    "XCBuildActionIdentifier": "RunScriptAction"
                }
            }
        ],
        "connectors": {},
        "workflowMetaData": {
            "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
            "workflowType": "com.apple.Automator.servicesMenu",
            "serviceApplicationBundleIdentifier": "com.apple.finder",
            "serviceApplicationPath": "/System/Library/CoreServices/Finder.app",
            "serviceInputTypeIdentifier": "com.apple.Automator.fileSystemObject",
            "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
            "serviceProcessesInput": True,
            "actionProvidesSelection": True
        }
    }

    with open(os.path.join(workflow_dir, "Contents", "document.wflow"), "wb") as f:
        plistlib.dump(wflow, f, fmt=plistlib.FMT_XML)

    print(f"Quick Action installed successfully at: {workflow_dir}")
    print("Run '/System/Library/CoreServices/pbs -update' manually if the menu does not appear immediately.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Install FinderSizePreview Quick Action")
    parser.add_argument("--app", default=os.path.abspath("FinderSizePreview.app"), help="Absolute path to the compiled FinderSizePreview.app")
    args = parser.parse_args()
    
    app_path = os.path.abspath(args.app)
    if not os.path.exists(app_path):
        print(f"Warning: App not found at {app_path}. The Action might not work until the app is built.")
        
    install_action(app_path)
