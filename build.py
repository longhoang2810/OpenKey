#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys
import glob

# Define directories
PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
SOURCES_ROOT = os.path.join(PROJECT_ROOT, "Sources", "OpenKey")
ENGINE_ROOT = os.path.join(SOURCES_ROOT, "engine")
MACOS_ROOT = os.path.join(SOURCES_ROOT, "macOS")
MODERNKEY_ROOT = os.path.join(MACOS_ROOT, "ModernKey")
HELPER_ROOT = os.path.join(MACOS_ROOT, "OpenKeyHelper")

BUILD_DIR = os.path.join(PROJECT_ROOT, "build_out")
APP_DIR = os.path.join(BUILD_DIR, "OpenKey.app")
APP_MACOS_DIR = os.path.join(APP_DIR, "Contents", "MacOS")
APP_LOGINITEMS_DIR = os.path.join(APP_DIR, "Contents", "Library", "LoginItems")
HELPER_APP_DIR = os.path.join(APP_LOGINITEMS_DIR, "OpenKeyHelper.app")
HELPER_MACOS_DIR = os.path.join(HELPER_APP_DIR, "Contents", "MacOS")

# Use the SDK of the active toolchain: a hard-coded CommandLineTools SDK can be newer than
# the selected Xcode linker, which then fails with "unknown architecture" in .tbd files.
SDK_PATH = subprocess.check_output(["xcrun", "--show-sdk-path"], text=True).strip()

def run_cmd(cmd, cwd=None):
    print(f"Running: {' '.join(cmd)}")
    res = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if res.returncode != 0:
        print(f"Error executing command: {' '.join(cmd)}")
        print(f"STDOUT:\n{res.stdout}")
        print(f"STDERR:\n{res.stderr}")
        sys.exit(1)
    return res.stdout

def copy_existing_app():
    if os.path.exists(BUILD_DIR):
        shutil.rmtree(BUILD_DIR)
    os.makedirs(BUILD_DIR, exist_ok=True)
    
    src_app = "/Applications/OpenKey.app"
    if not os.path.exists(src_app):
        print(f"Error: Base application not found at {src_app}.")
        sys.exit(1)
        
    print(f"Copying baseline application from {src_app}...")
    shutil.copytree(src_app, APP_DIR, symlinks=True)

def compile_helper():
    print("Compiling OpenKeyHelper executable...")
    sources = [
        os.path.join(HELPER_ROOT, "main.m"),
        os.path.join(HELPER_ROOT, "AppDelegate.m")
    ]
    output = os.path.join(HELPER_MACOS_DIR, "OpenKeyHelper")
    
    # Remove existing binary first
    if os.path.exists(output):
        os.remove(output)
        
    cmd = [
        "clang",
        "-arch", "arm64",
        "-arch", "x86_64",
        "-fobjc-arc",
        "-isysroot", SDK_PATH,
        "-framework", "Cocoa",
        "-I", HELPER_ROOT,
        *sources,
        "-o", output
    ]
    run_cmd(cmd)

def compile_main_app():
    print("Compiling main OpenKey executable...")
    
    # Temporary object file directory
    obj_dir = os.path.join(BUILD_DIR, "objs")
    if os.path.exists(obj_dir):
        shutil.rmtree(obj_dir)
    os.makedirs(obj_dir, exist_ok=True)
    
    # Engine C++ sources
    engine_sources = glob.glob(os.path.join(ENGINE_ROOT, "*.cpp"))
    
    # ModernKey Obj-C/Obj-C++ sources
    modernkey_sources = (
        glob.glob(os.path.join(MODERNKEY_ROOT, "*.m")) +
        glob.glob(os.path.join(MODERNKEY_ROOT, "*.mm"))
    )

    output = os.path.join(APP_MACOS_DIR, "OpenKey")
    
    # Remove existing binary first
    if os.path.exists(output):
        os.remove(output)
        
    # Compile C++ files
    print("Compiling C++ sources...")
    for src in engine_sources:
        obj_name = os.path.basename(src).replace(".cpp", ".o")
        obj_path = os.path.join(obj_dir, obj_name)
        cmd = [
            "clang++",
            "-arch", "arm64",
            "-arch", "x86_64",
            "-std=c++11",
            "-O3",
            "-isysroot", SDK_PATH,
            "-I", ENGINE_ROOT,
            "-I", os.path.join(ENGINE_ROOT, "platforms"),
            "-I", MODERNKEY_ROOT,
            "-c", src,
            "-o", obj_path
        ]
        run_cmd(cmd)

    # Compile Obj-C/Obj-C++ files
    print("Compiling Objective-C and Objective-C++ sources...")
    for src in modernkey_sources:
        ext = ".mm" if src.endswith(".mm") else ".m"
        obj_name = os.path.basename(src).replace(ext, ".o")
        obj_path = os.path.join(obj_dir, obj_name)
        
        cmd = [
            "clang++",
            "-arch", "arm64",
            "-arch", "x86_64",
            "-fobjc-arc",
            "-O3",
            "-isysroot", SDK_PATH,
            "-I", ENGINE_ROOT,
            "-I", os.path.join(ENGINE_ROOT, "platforms"),
            "-I", MODERNKEY_ROOT,
            "-c", src,
            "-o", obj_path
        ]
        # Add c++11 std flag only if it is Obj-C++ (.mm)
        if ext == ".mm":
            cmd.insert(5, "-std=c++11")
            
        run_cmd(cmd)

    # Link everything
    print("Linking all object files...")
    obj_files = glob.glob(os.path.join(obj_dir, "*.o"))
    
    cmd = [
        "clang++",
        "-arch", "arm64",
        "-arch", "x86_64",
        "-fobjc-arc",
        "-O3",
        "-isysroot", SDK_PATH,
        "-framework", "Cocoa",
        "-framework", "Carbon",
        "-framework", "InputMethodKit",
        "-framework", "ServiceManagement",
        *obj_files,
        "-o", output
    ]
    run_cmd(cmd)
    
    # Clean up object files
    shutil.rmtree(obj_dir)

def compile_storyboard():
    # The baseline bundle ships an old compiled storyboard; rebuild it so UI changes land.
    print("Compiling storyboard...")
    output = os.path.join(APP_DIR, "Contents", "Resources", "Base.lproj", "Main.storyboardc")
    if os.path.exists(output):
        shutil.rmtree(output)
    run_cmd(["xcrun", "ibtool", "--errors", "--compile", output,
             os.path.join(MODERNKEY_ROOT, "Base.lproj", "Main.storyboard")])

def codesign_apps():
    print("Performing ad-hoc codesigning...")
    
    # Sign helper app binary and bundle
    helper_bin = os.path.join(HELPER_MACOS_DIR, "OpenKeyHelper")
    run_cmd(["codesign", "--force", "--sign", "-", helper_bin])
    run_cmd(["codesign", "--force", "--sign", "-", HELPER_APP_DIR])

    # Sign main app binary and bundle
    main_bin = os.path.join(APP_MACOS_DIR, "OpenKey")
    run_cmd(["codesign", "--force", "--sign", "-", main_bin])
    run_cmd(["codesign", "--force", "--sign", "-", APP_DIR])

def main():
    print("=== STARTING BUILD PROCESS ===")
    copy_existing_app()
    compile_helper()
    compile_main_app()
    compile_storyboard()
    codesign_apps()
    
    print("\n=== BUILD COMPLETED SUCCESSFULLY ===")
    print(f"Improved application ready at: {APP_DIR}")

if __name__ == "__main__":
    main()
