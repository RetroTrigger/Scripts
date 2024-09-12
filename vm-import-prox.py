import os
import sys
import subprocess

# Ensure pythondialog is installed
def install_pythondialog():
    try:
        import dialog
    except ImportError:
        print("pythondialog is not installed. Attempting to install it...")

        # Check if pip is installed, if not, install pip
        try:
            subprocess.check_call([sys.executable, "-m", "ensurepip", "--upgrade"])
        except subprocess.CalledProcessError:
            print("Failed to install pip automatically. Please install pip manually and rerun the script.")
            sys.exit(1)

        # Now, try to install pythondialog
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "pythondialog"])
            print("pythondialog installed successfully. Please rerun the script.")
            sys.exit(0)
        except subprocess.CalledProcessError:
            print("Failed to install pythondialog. Please install it manually and rerun the script.")
            sys.exit(1)

install_pythondialog()

from dialog import Dialog

d = Dialog(dialog="dialog")

def check_root():
    if os.geteuid() != 0:
        d.msgbox("This script must be run as root. Please use sudo or run as root.")
        exit(1)

def install_nfs_utilities():
    if subprocess.run(["which", "exportfs"], capture_output=True).returncode != 0:
        d.infobox("NFS utilities are not installed. Installing NFS utilities...")
        if os.path.exists("/etc/debian_version"):
            subprocess.run(["apt", "update"], check=True)
            subprocess.run(["apt", "install", "-y", "nfs-kernel-server"], check=True)
        elif os.path.exists("/etc/redhat-release"):
            subprocess.run(["yum", "install", "-y", "nfs-utils"], check=True)
        else:
            d.msgbox("Unsupported operating system. Please install the NFS utilities manually.")
            exit(1)
    else:
        d.msgbox("NFS utilities are already installed.")

    d.infobox("Starting and enabling NFS server...")
    subprocess.run(["systemctl", "start", "nfs-kernel-server"], check=True)
    subprocess.run(["systemctl", "enable", "nfs-kernel-server"], check=True)

def configure_nfs_exports(template_dir):
    export_entry = f"{template_dir} *(rw,sync,no_subtree_check,no_root_squash)"
    exports_file = "/etc/exports"

    with open(exports_file, "r") as file:
        lines = file.readlines()

    with open(exports_file, "w") as file:
        for line in lines:
            if template_dir not in line:
                file.write(line)
        file.write(f"{export_entry}\n")

    subprocess.run(["exportfs", "-ra"], check=True)
    subprocess.run(["systemctl", "restart", "nfs-kernel-server"], check=True)

def menu():
    code, choice = d.menu("Choose an option:", choices=[("1", "Convert and create VM"),
                                                        ("2", "Download VulnHub template"),
                                                        ("3", "Manage VMs"),
                                                        ("4", "Exit")])

    if code == d.OK:
        if choice == "1":
            convert_and_create_vm()
        elif choice == "2":
            download_vuln()
        elif choice == "3":
            manage_vms()
        elif choice == "4":
            d.msgbox("Exiting...")
            sys.exit(0)
        else:
            d.msgbox("Invalid option. Please try again.")
    else:
        d.msgbox("Cancelled by user.")
        sys.exit(1)

def convert_and_create_vm():
    code, vm_id = d.inputbox("Enter VM ID:")
    if code == d.OK:
        code, vm_name = d.inputbox("Enter VM name:")
        if code == d.OK:
            code, template_file = d.fselect("/path/to/templates", height=15, width=60)
            if code == d.OK:
                code, storage_type = d.radiolist("Select storage type:",
                                                 choices=[("1", "LVM-Thin", True),
                                                          ("2", "Directory", False)])
                if code == d.OK:
                    d.msgbox(f"Converting and creating VM {vm_name} with ID {vm_id}...")
                else:
                    d.msgbox("Storage type selection cancelled.")
            else:
                d.msgbox("Template file selection cancelled.")
        else:
            d.msgbox("VM name input cancelled.")
    else:
        d.msgbox("VM ID input cancelled.")

def download_vuln():
    code, download_link = d.inputbox("Enter the download link:")
    if code == d.OK:
        d.msgbox(f"Downloading template from {download_link}...")
    else:
        d.msgbox("Download cancelled.")

def manage_vms():
    d.msgbox("Managing VMs...")

if __name__ == "__main__":
    check_root()
    install_nfs_utilities()

    template_dir = "/var/lib/vz/template/imported_templates"
    if not os.path.exists(template_dir):
        os.makedirs(template_dir)
    os.chmod(template_dir, 0o775)

    configure_nfs_exports(template_dir)
    d.msgbox("NFS configuration is complete. Proceeding to the menu...")

    menu()
